//
//	COPYRIGHT 2000 by Bruce L. Jacob
//	(contact info: http://www.ece.umd.edu/~blj/)
//
//	You are welcome to use, modify, copy, and/or redistribute this implementation, provided:
//	  1. you share with the author (Bruce Jacob) any changes you make;
//	  2. you properly credit the author (Bruce Jacob) if used within a larger work; and
//	  3. you do not modify, delete, or in any way obscure the implementation's copyright 
//	     notice or following comments (i.e. the first 3-4 dozen lines of this file).
//
//	RiSC-16
//
//	This is an out-of-order implementation of the RiSC-16, a teaching instruction-set used by
//	the author at the University of Maryland, and which is a blatant (but sanctioned) rip-off
//	of the Little Computer (LC-896) developed by Peter Chen at the University of Michigan.
//	The primary differences include the following:
//	  1. a move from 17-bit to 16-bit instructions; and
//	  2. the replacement of the NOP and HALT opcodes by ADDI and LUI ... HALT and NOP are
//	     now simply special instances of other instructions: NOP is a do-nothing ADD, and
//	     HALT is a subset of JALR.
//
//	RiSC stands for Ridiculously Simple Computer, which makes sense in the context in which
//	the instruction-set is normally used -- to teach simple organization and architecture to
//	undergraduates who do not yet know how computers work.  This implementation was targetted
//	towards more advanced undergraduates doing design & implementation and was intended to 
//	demonstrate some high-performance concepts on a small scale -- an 8-entry reorder buffer,
//	eight opcodes, two ALUs, two-way issue, two-way commit, etc.  However, the out-of-order 
//	core is much more complex than I anticipated, and I hope that its complexity does not 
//	obscure its underlying structure.  We'll see how well it flies in class ...
//
//	CAVEAT FREELOADER: This Verilog implementation was developed and debugged in a (somewhat
//	frantic) 2-week period before the start of the Fall 2000 semester.  Not surprisingly, it
//	still contains many bugs and some horrible, horrible logic.  The logic is also written so
//	as to be debuggable and/or explain its function, rather than to be efficient -- e.g. in
//	several places, signals are over-constrained so that they are easy to read in the debug
//	output ... also, you will see statements like
//
//	    if (xyz[`INSTRUCTION_OP] == `BEQ || xyz[`INSTRUCTION_OP] == `SW)
//
//	instead of and/nand combinations of bits ... sorry; can't be helped.  Use at your own risk.
//
//	DOCUMENTATION: Documents describing the RiSC-16 in all its forms (sequential, pipelined,
//	as well as out-of-order) can be found on the author's website at the following URL:
//
//	    http://www.ece.umd.edu/~blj/RiSC/
//
//	If you do not find what you are looking for, please feel free to email me with suggestions
//	for more/different/modified documents.  Same goes for bug fixes.
//
//
//	KNOWN PROBLEMS (i.e., bugs I haven't got around to fixing yet)
//
//	- If the target of a backwards branch is a backwards branch, the fetchbuf steering logic
//	  will get confused.  This can be fixed by having a separate did_branchback status register
//	  for each of the fetch buffers.
//
// ============================================================================
//        __
//   \\__/ o\    (C) 2017  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	FT64.v
//	Modification to RiSC-16 include:
//  - move to 32 bit instructions
//  - additional instructions added
//  - immediate prefix instructions for larger immediates
//  - extension of data width to 64 bits
//  - dual result busses
//  - addition of more powerful branch prediction
//  - bus interface unit
//  - instruction and data caches
//  - asynchronous logic loops for issue and branch miss
//    re-written for synchronous operation, not as elegant
//    but required for operation in an FPGA
//		
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
//                                                                          
// ============================================================================
//
`include "FT64_defines.vh"

module FT64(hartid, rst, clk, irq_i, vec_i, cyc_o, stb_o, ack_i, we_o, sel_o, adr_o, dat_o, dat_i,
    ol_o, pcr_o, pcr2_o, exv_i, rdv_i, wrv_i, icl_o, sr_o, cr_o, rbi_i);
input [63:0] hartid;
input rst;
input clk;
input [2:0] irq_i;
input [8:0] vec_i;
output reg cyc_o;
output reg stb_o;
input ack_i;
output reg we_o;
output reg [7:0] sel_o;
output reg [31:0] adr_o;
output reg [63:0] dat_o;
input [63:0] dat_i;
output [2:0] ol_o;
output [31:0] pcr_o;
output [63:0] pcr2_o;
input exv_i;
input rdv_i;
input wrv_i;
output reg icl_o;
output reg cr_o;
output reg sr_o;
input rbi_i;

parameter QENTRIES = 8;
parameter RSTPC = 32'hFFFC0100;
parameter BRKPC = 32'hFFFC0000;
parameter PREGS = 31;   // number of physical registers - 1
parameter AREGS = 32;   // number of architectural registers
parameter DEBUG = 1'b0;
parameter NMAP = QENTRIES;
reg [3:0] i;
integer n;
integer j;
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
// Memory access sizes
parameter byt = 3'd0;
parameter wyde = 3'd1;
parameter tetra = 3'd2;
parameter octa = 3'd3;

wire [5:0] Ra0, Ra1;
wire [5:0] Rb0, Rb1;
wire [5:0] Rc0, Rc1;
wire [5:0] Rt0, Rt1;
wire [5:0] Rt0b, Rt1b;
wire [63:0] rfoa0,rfob0,rfoc0;
wire [63:0] rfoa1,rfob1,rfoc1;
reg  [31:0] rf_v;
reg  [4:0] rf_source[0:31];
reg [31:0] pc0;
reg [31:0] pc1;

reg exception_set;
// CSR's
reg [2:0] ol;           // operating level
assign ol_o = ol;
reg [7:0] cpl;          // current privilege level
reg [63:0] tick;
reg [31:0] pcr;
reg [63:0] pcr2;
assign pcr_o = pcr;
assign pcr2_o = pcr2;
reg [15:0] cause[0:7];
reg [31:0] epc,epc0,epc1,epc2,epc3,epc4,epc5,epc6,epc7,epc8; // exception pc and stack
reg [127:0] mstatus;     // machine status
reg [31:0] badaddr[0:7];
reg [31:0] tvec[0:7];
reg [63:0] sema;
//reg [25:0] m[0:8191];
reg  [3:0] panic;		// indexes the message structure
reg [128:0] message [0:15];	// indexed by panic

reg [2:0] im;
wire int_commit;
reg StatusHWI;
reg [31:0] insn0, insn1;
wire [31:0] insn0a, insn1a;
// Only need enough bits in the seqnence number to cover the instructions in
// the queue plus an extra count for skipping on branch misses. In this case
// that would be four bits minimum (count 0 to 8). 
reg [4:0] seq_num;
wire [63:0] rdat0,rdat1,rdat2;
reg [63:0] xdati;

reg queued1;
reg queued2;
reg queuedNop;

reg [31:0] codebuf[0:63];

// instruction queue (ROB)
reg [4:0]  iqentry_sn   [0:7];  // instruction sequence number
reg        iqentry_v  	[0:7];	// entry valid?  -- this should be the first bit
reg        iqentry_out	[0:7];	// instruction has been issued to an ALU ... 
reg        iqentry_done	[0:7];	// instruction result valid
reg        iqentry_bt  	[0:7];	// branch-taken (used only for branches)
reg        iqentry_agen  	[0:7];	// address-generate ... signifies that address is ready (only for LW/SW)
reg        iqentry_alu  [0:7];  // alu type instruction
reg        iqentry_fc   [0:7];   // flow control instruction
reg        iqentry_mem	[0:7];	// touches memory: 1 if LW/SW
reg        iqentry_memndx   [0:7];  // indexed memory operation 
reg        iqentry_memdb    [0:7];
reg        iqentry_memsb    [0:7];
reg        iqentry_jmp	[0:7];	// changes control flow: 1 if BEQ/JALR
reg        iqentry_br   [0:7];  // Bcc (for predictor)
reg        iqentry_fp   [0:7];  // floating point
reg        iqentry_sync [0:7];  // sync instruction
reg        iqentry_rfw	[0:7];	// writes to register file
reg [63:0] iqentry_res	[0:7];	// instruction result
reg [63:0] iqentry_res2	[0:7];	// instruction result
reg [31:0] iqentry_instr[0:7];	// instruction opcode
reg  [3:0] iqentry_exc	[0:7];	// only for branches ... indicates a HALT instruction
reg  [5:0] iqentry_tgt	[0:7];	// Rt field or ZERO -- this is the instruction's target (if any)
reg  [5:0] iqentry_tgt2	[0:7];	// Rt field or ZERO -- this is the instruction's target (if any)
reg [63:0] iqentry_a0	[0:7];	// argument 0 (immediate)
reg [63:0] iqentry_a1	[0:7];	// argument 1
reg        iqentry_a1_v	[0:7];	// arg1 valid
reg  [4:0] iqentry_a1_s	[0:7];	// arg1 source (iq entry # with top bit representing ALU/DRAM bus)
reg [63:0] iqentry_a2	[0:7];	// argument 2
reg        iqentry_a2_v	[0:7];	// arg2 valid
reg  [4:0] iqentry_a2_s	[0:7];	// arg2 source (iq entry # with top bit representing ALU/DRAM bus)
reg [63:0] iqentry_a3	[0:7];	// argument 3
reg        iqentry_a3_v	[0:7];	// arg3 valid
reg  [4:0] iqentry_a3_s	[0:7];	// arg3 source (iq entry # with top bit representing ALU/DRAM bus)
reg [31:0] iqentry_pc	[0:7];	// program counter for this instruction
// debugging
//reg  [4:0] iqentry_ra   [0:7];  // Ra
reg [4:0]  iqentry_utgt [0:7];  // unrenamed target register

wire  [7:0] iqentry_source;
wire  [7:0] iqentry_imm;
wire  [7:0] iqentry_memready;
wire  [7:0] iqentry_memopsvalid;

reg  [7:0] iqentry_memissue;
wire  [7:0] iqentry_stomp;
reg  [7:0] iqentry_issue;
reg [1:0] iqentry_islot [0:7];
reg [7:0] iqentry_fcu_issue;

wire [PREGS:1] livetarget;
wire  [PREGS:1] iqentry_0_livetarget;
wire  [PREGS:1] iqentry_1_livetarget;
wire  [PREGS:1] iqentry_2_livetarget;
wire  [PREGS:1] iqentry_3_livetarget;
wire  [PREGS:1] iqentry_4_livetarget;
wire  [PREGS:1] iqentry_5_livetarget;
wire  [PREGS:1] iqentry_6_livetarget;
wire  [PREGS:1] iqentry_7_livetarget;
wire  [PREGS:1] iqentry_0_latestID;
wire  [PREGS:1] iqentry_1_latestID;
wire  [PREGS:1] iqentry_2_latestID;
wire  [PREGS:1] iqentry_3_latestID;
wire  [PREGS:1] iqentry_4_latestID;
wire  [PREGS:1] iqentry_5_latestID;
wire  [PREGS:1] iqentry_6_latestID;
wire  [PREGS:1] iqentry_7_latestID;
wire  [PREGS:1] iqentry_0_cumulative;
wire  [PREGS:1] iqentry_1_cumulative;
wire  [PREGS:1] iqentry_2_cumulative;
wire  [PREGS:1] iqentry_3_cumulative;
wire  [PREGS:1] iqentry_4_cumulative;
wire  [PREGS:1] iqentry_5_cumulative;
wire  [PREGS:1] iqentry_6_cumulative;
wire  [PREGS:1] iqentry_7_cumulative;
wire  [PREGS:1] iq0_out;
wire  [PREGS:1] iq1_out;
wire  [PREGS:1] iq2_out;
wire  [PREGS:1] iq3_out;
wire  [PREGS:1] iq4_out;
wire  [PREGS:1] iq5_out;
wire  [PREGS:1] iq6_out;
wire  [PREGS:1] iq7_out;

reg  [2:0] tail0, tail0a;
reg  [2:0] tail1, tail1a;
reg  [2:0] head0;
reg  [2:0] head1;
reg  [2:0] head2;	// used only to determine memory-access ordering
reg  [2:0] head3;	// used only to determine memory-access ordering
reg  [2:0] head4;	// used only to determine memory-access ordering
reg  [2:0] head5;	// used only to determine memory-access ordering
reg  [2:0] head6;	// used only to determine memory-access ordering
reg  [2:0] head7;	// used only to determine memory-access ordering

wire  [2:0] missid;

reg        fetchbuf;	// determines which pair to read from & write to

wire [31:0] fetchbuf0_instr;	
wire [31:0] fetchbuf0_pc;
wire        fetchbuf0_v;
wire        fetchbuf0_mem;
wire        fetchbuf0_jmp;
wire        fetchbuf0_rfw;
wire [31:0] fetchbuf1_instr;
wire [31:0] fetchbuf1_pc;
wire        fetchbuf1_v;
wire        fetchbuf1_mem;
wire        fetchbuf1_jmp;
wire        fetchbuf1_rfw;

reg [31:0] fetchbufA_instr;	
reg [31:0] fetchbufA_pc;
reg        fetchbufA_v;
reg [31:0] fetchbufB_instr;
reg [31:0] fetchbufB_pc;
reg        fetchbufB_v;
reg [31:0] fetchbufC_instr;
reg [31:0] fetchbufC_pc;
reg        fetchbufC_v;
reg [31:0] fetchbufD_instr;
reg [31:0] fetchbufD_pc;
reg        fetchbufD_v;

reg        did_branchback0;
reg        did_branchback1;

reg        alu0_ld;
reg        alu0_available;
reg        alu0_dataready;
wire       alu0_done;
wire       alu0_idle;
reg  [3:0] alu0_sourceid;
reg [31:0] alu0_instr;
reg        alu0_bt;
reg [63:0] alu0_argA;
reg [63:0] alu0_argB;
reg [63:0] alu0_argC;
reg [63:0] alu0_argI;	// only used by BEQ
reg [31:0] alu0_pc;
wire [63:0] alu0_bus;
wire [63:0] alu0b_bus;
wire  [3:0] alu0_id;
wire  [8:0] alu0_exc;
wire        alu0_v;
wire        alu0_branchmiss;
wire [31:0] alu0_misspc;

reg        alu1_ld;
reg        alu1_available;
reg        alu1_dataready;
wire       alu1_done;
wire       alu1_idle;
reg  [3:0] alu1_sourceid;
reg [31:0] alu1_instr;
reg        alu1_bt;
reg [63:0] alu1_argA;
reg [63:0] alu1_argB;
reg [63:0] alu1_argC;
reg [63:0] alu1_argI;	// only used by BEQ
reg [31:0] alu1_pc;
wire [63:0] alu1_bus;
wire [63:0] alu1b_bus;
wire  [3:0] alu1_id;
wire  [8:0] alu1_exc;
wire        alu1_v;
wire        alu1_branchmiss;
wire [31:0] alu1_misspc;

reg        fcu_dataready;
wire       fcu_done = 1'b1;
reg         fcu_idle = 1'b1;
reg  [3:0] fcu_sourceid;
reg [31:0] fcu_instr;
reg        fcu_bt;
reg [63:0] fcu_argA;
reg [63:0] fcu_argB;
reg [63:0] fcu_argC;
reg [63:0] fcu_argI;	// only used by BEQ
reg [31:0] fcu_pc;
reg [63:0] fcu_bus;
reg [63:0] fcu_bbus;
wire  [3:0] fcu_id;
reg   [8:0] fcu_exc;
wire        fcu_v;
wire        fcu_branchmiss;
wire [31:0] fcu_misspc;

wire [31:0] backpc; // for debug display
reg [31:0] branch_pc;
wire        branchmiss;
wire [31:0] misspc;
wire take_branch;
wire take_branchA;
wire take_branchB;
wire take_branchC;
wire take_branchD;

wire        dram_avail;
reg	 [1:0] dram0;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	 [1:0] dram1;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	 [1:0] dram2;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg [63:0] dram0_data;
reg [31:0] dram0_addr;
reg [31:0] dram0_instr;
reg  [5:0] dram0_tgt;
reg  [3:0] dram0_id;
reg  [8:0] dram0_exc;
reg        dram0_unc;
reg [2:0]  dram0_memsize;
reg [63:0] dram1_data;
reg [31:0] dram1_addr;
reg [31:0] dram1_instr;
reg  [5:0] dram1_tgt;
reg  [3:0] dram1_id;
reg  [8:0] dram1_exc;
reg        dram1_unc;
reg [2:0]  dram1_memsize;
reg [63:0] dram2_data;
reg [31:0] dram2_addr;
reg [31:0] dram2_instr;
reg  [5:0] dram2_tgt;
reg  [3:0] dram2_id;
reg  [8:0] dram2_exc;
reg        dram2_unc;
reg [2:0]  dram2_memsize;

reg [63:0] dram_bus;
reg  [5:0] dram_tgt;
reg        dram_tgtpc;
reg  [3:0] dram_id;
reg  [8:0] dram_exc;
reg        dram_v;

wire        outstanding_stores;
reg [63:0] I;	// instruction count

reg        commit0_v;
reg  [4:0] commit0_id;
reg  [5:0] commit0_tgt;
reg [63:0] commit0_bus;
reg        commit1_v;
reg  [4:0] commit1_id;
reg  [5:0] commit1_tgt;
reg [63:0] commit1_bus;

reg [4:0] bstate;
parameter BIDLE = 5'd0;
parameter B1 = 5'd1;
parameter B2 = 5'd2;
parameter B3 = 5'd3;
parameter B4 = 5'd4;
parameter B5 = 5'd5;
parameter B6 = 5'd6;
parameter B7 = 5'd7;
parameter B8 = 5'd8;
parameter B9 = 5'd9;
parameter B10 = 5'd10;
parameter B11 = 5'd11;
parameter B12 = 5'd12;
parameter B13 = 5'd13;
parameter B14 = 5'd14;
parameter B15 = 5'd15;
parameter B16 = 5'd16;
parameter B17 = 5'd17;
parameter B18 = 5'd18;
parameter B19 = 5'd19;
parameter B2a = 5'd20;
parameter B2b = 5'd21;
parameter B2c = 5'd22;
parameter B2d = 5'd23;
reg [1:0] bwhich;
reg [3:0] icstate,picstate;
parameter IDLE = 4'd0;
parameter IC1 = 4'd1;
parameter IC2 = 4'd2;
parameter IC3 = 4'd3;
parameter IC4 = 4'd4;
parameter IC5 = 4'd5;
parameter IC6 = 4'd6;
parameter IC7 = 4'd7;
parameter IC8 = 4'd8;
parameter IC9 = 4'd9;
parameter IC10 = 4'd10;
parameter IC3a = 4'd11;
reg icwhich,icnxt,L2_nxt;
wire ihit0,ihit1,ihit2;
wire ihit = ihit0&ihit1;
wire phit = ihit&&icstate==IDLE;
reg L1_wr0,L1_wr1;
reg [37:0] L1_adr, L2_adr;
reg [255:0] L2_rdat;
wire [255:0] L2_dato;

FT64_regfile2w6r urf1
(
    .clk(clk),
    .wr0(commit0_v),
    .wr1(commit1_v),
    .wa0(commit0_tgt),
    .wa1(commit1_tgt),
    .i0(commit0_bus),
    .i1(commit1_bus),
	.rclk(~clk),
	.ra0(Ra0),
	.ra1(Rb0),
	.ra2(Rc0),
	.ra3(Ra1),
	.ra4(Rb1),
	.ra5(Rc1),
	.o0(rfoa0),
	.o1(rfob0),
	.o2(rfoc0),
	.o3(rfoa1),
	.o4(rfob1),
	.o5(rfoc1)
);

FT64_L1_icache uic0
(
    .rst(rst),
    .clk(clk),
    .nxt(icnxt),
    .wr(L1_wr0),
    .adr(icstate==IDLE ? pc0 : L1_adr),
    .i(L2_rdat),
    .o(insn0a),
    .hit(ihit0),
    .invall(),
    .invline()
);
FT64_L1_icache uic1
(
    .rst(rst),
    .clk(clk),
    .wr(L1_wr1),
    .adr(icstate==IDLE ? pc1 : L1_adr),
    .i(L2_rdat),
    .o(insn1a),
    .hit(ihit1),
    .invall(),
    .invline()
);
FT64_L2_icache uic2
(
    .rst(rst),
    .clk(clk),
    .nxt(L2_nxt),
    .wr(bstate==B7 && ack_i),
    .adr(L2_adr),
    .i(exv_i ? {2{16'd0,1'b0,`FLT_EXF,`BRK}} : dat_i),
    .o(L2_dato),
    .hit(ihit2),
    .invall(),
    .invline()
);

wire predict_taken;
wire predict_takenA;
wire predict_takenB;
wire predict_takenC;
wire predict_takenD;
FT64BranchPredictor ubp1
(
    .rst(rst),
    .clk(clk),
    .xisBranch0(iqentry_br[head0]),
    .xisBranch1(iqentry_br[head1]),
    .pcA(fetchbufA_pc),
    .pcB(fetchbufB_pc),
    .pcC(fetchbufC_pc),
    .pcD(fetchbufD_pc),
    .xpc0(iqentry_pc[head0]),
    .xpc1(iqentry_pc[head1]),
    .takb0(commit0_v),
    .takb1(commit1_v),
    .predict_takenA(predict_takenA),
    .predict_takenB(predict_takenB),
    .predict_takenC(predict_takenC),
    .predict_takenD(predict_takenD)
);

always @*
if ((irq_i > im) && ~int_commit)
	insn0 <= {13'd0,irq_i,1'b0,vec_i,`BRK};
else if (phit)
    insn0 <= insn0a;
else
    insn0 <= `NOP_INSN;
always @*
if ((irq_i > im) && ~int_commit)
    insn1 <= {13'd0,irq_i,1'b0,vec_i,`BRK};
else if (phit)
    insn1 <= insn1a;
else
    insn1 <= `NOP_INSN;

wire [63:0] dc0_out, dc1_out, dc2_out;
assign rdat0 = dram0_unc ? xdati : dc0_out;
assign rdat1 = dram1_unc ? xdati : dc1_out;
assign rdat2 = dram2_unc ? xdati : dc2_out;

wire dhit0, dhit1, dhit2;
wire dhit00, dhit10, dhit20;
wire dhit01, dhit11, dhit21;
reg [31:0] dc_wadr;
reg [63:0] dc_wdat;

FT64_dcache udc0
(
    .rst(rst),
    .wclk(clk),
    .wr((bstate==B2d||(bstate==B1 && dhit0)) && ack_i),
    .sel(sel_o),
    .wadr({pcr[5:0],adr_o}),
    .i(bstate==B2 ? dat_i : dat_o),
    .rclk(clk),
    .rdsize(dram0_memsize),
    .radr({pcr[5:0],dram0_addr}),
    .o(dc0_out),
    .hit(),
    .hit0(dhit0),
    .hit1()
);
FT64_dcache udc1
(
    .rst(rst),
    .wclk(clk),
    .wr((bstate==B2d||(bstate==B1 && dhit1)) && ack_i),
    .sel(sel_o),
    .wadr({pcr[5:0],adr_o}),
    .i(bstate==B2 ? dat_i : dat_o),
    .rclk(clk),
    .rdsize(dram1_memsize),
    .radr({pcr[5:0],dram1_addr}),
    .o(dc1_out),
    .hit(),
    .hit0(dhit1),
    .hit1()
);
FT64_dcache udc2
(
    .rst(rst),
    .wclk(clk),
    .wr((bstate==B2d||(bstate==B1 && dhit2)) && ack_i),
    .sel(sel_o),
    .wadr({pcr[5:0],adr_o}),
    .i(bstate==B2 ? dat_i : dat_o),
    .rclk(clk),
    .rdsize(dram2_memsize),
    .radr({pcr[5:0],dram2_addr}),
    .o(dc2_out),
    .hit(),
    .hit0(dhit2),
    .hit1()
);

function [2:0] MapInc;
input [2:0] ndx;
input [2:0] amt;
reg [3:0] s;
begin
s = ndx + amt;
if (s >= {1'b0,NMAP})
    MapInc = s - NMAP;
else
    MapInc = s;
end
endfunction

function [4:0] fnRa;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:    case(isn[`INSTRUCTION_S2])
        default:    fnRa = isn[`INSTRUCTION_RA];
        endcase
`CALL:  fnRa = 6'd31;
default:    fnRa = isn[`INSTRUCTION_RA];
endcase
endfunction

function [4:0] fnRb;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:    fnRb = isn[`INSTRUCTION_RB];
default:    fnRb = isn[`INSTRUCTION_RB];
endcase
endfunction

function [4:0] fnRc;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:    fnRc = isn[`INSTRUCTION_RC];
default:    fnRc = isn[`INSTRUCTION_RC];
endcase
endfunction

function [4:0] fnRt;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:    case(isn[`INSTRUCTION_S2])
        `PUSH:      fnRt = 6'd0;
        `POP:       fnRt = isn[`INSTRUCTION_RB];
        `CMOVEQ:    fnRt = isn[`INSTRUCTION_S1];
        `CMOVNE:    fnRt = isn[`INSTRUCTION_S1];
        `MUX:       fnRt = isn[`INSTRUCTION_S1];
        default:    fnRt = isn[`INSTRUCTION_RC];
        endcase
`CALL:  fnRt = 6'd31;
`RET:   fnRt = 6'd0;
default:    fnRt = isn[`INSTRUCTION_RB];
endcase
endfunction

function [5:0] fnRt2;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:    case(isn[`INSTRUCTION_S2])
        `PUSH,`POP:   fnRt2 = isn[`INSTRUCTION_RC];
        default:    fnRt2 = 6'd0;
        endcase
`RET:   fnRt2 = isn[`INSTRUCTION_RB];
default:    fnRt2 = 6'd0;
endcase
endfunction

function Source1Valid;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`BRK:   Source1Valid = TRUE;
`Bcc:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`RR:    case(isn[`INSTRUCTION_S2])
        `SHLI:     Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
        `SHRI:     Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
        default:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
        endcase
`ADDI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`CMPI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`CMPUI: Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`ANDI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`ORI:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`XORI:  Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`MULUI: Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LH:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LHU:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`LW:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SH:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`SW:    Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`JAL:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
`CALL:  Source1Valid = FALSE;
`RET:   Source1Valid = isn[`INSTRUCTION_RA]==5'd0;
default:    Source1Valid = TRUE;
endcase
endfunction
  
function Source2Valid;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`BRK:   Source2Valid = TRUE;
`Bcc:   Source2Valid = TRUE;
`RR:    case(isn[`INSTRUCTION_S2])
        `POP:      Source2Valid = TRUE;
        `SHLI:     Source2Valid = TRUE;
        `SHRI:     Source2Valid = TRUE;
        default:   Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
        endcase
`ADDI:  Source2Valid = TRUE;
`CMPI:  Source2Valid = TRUE;
`CMPUI: Source2Valid = TRUE;
`ANDI:  Source2Valid = TRUE;
`ORI:   Source2Valid = TRUE;
`XORI:  Source2Valid = TRUE;
`MULUI: Source2Valid = TRUE;
`LH:    Source2Valid = TRUE;
`LHU:   Source2Valid = TRUE;
`LW:    Source2Valid = TRUE;
`SH:    Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`SW:    Source2Valid = isn[`INSTRUCTION_RB]==5'd0;
`JAL:   Source2Valid = TRUE;
`RET:   Source2Valid = TRUE;
default:    Source2Valid = TRUE;
endcase
endfunction

function Source3Valid;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `SBX:       Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    `SHX:       Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    `SWX:       Source3Valid = isn[`INSTRUCTION_RC]==5'd0;
    default:    Source3Valid = TRUE;
    endcase
default:    Source3Valid = TRUE;
endcase
endfunction

function IsALU;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:    case(isn[`INSTRUCTION_S2])
        `RTI:       IsALU = FALSE;
        default:    IsALU = TRUE;
        endcase
`BRK:   IsALU = FALSE;
`Bcc:   IsALU = FALSE;
`JAL:   IsALU = FALSE;
`CALL:  IsALU = FALSE;
`RET:   IsALU = TRUE;
default:    IsALU = TRUE;
endcase
endfunction

function HasConst;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`BRK:   HasConst = FALSE;
`Bcc:   HasConst = FALSE;
`RR:    case(isn[`INSTRUCTION_S2])
        `SHLI:  HasConst = TRUE;
        `SHRI:  HasConst = TRUE;
        default: HasConst = FALSE;
        endcase
`ADDI:  HasConst = TRUE;
`CMPI:  HasConst = TRUE;
`CMPUI:  HasConst = TRUE;
`ANDI:  HasConst = TRUE;
`ORI:  HasConst = TRUE;
`XORI:  HasConst = TRUE;
`MULUI: HasConst = TRUE;
`MULSUI:    HasConst = TRUE;
`MULI:  HasConst = TRUE;
`DIVUI: HasConst = TRUE;
`DIVSUI:    HasConst = TRUE;
`DIVI:  HasConst = TRUE;
`MODUI: HasConst = TRUE;
`MODSUI:    HasConst = TRUE;
`MODI:  HasConst = TRUE;
`LB:    HasConst = TRUE;
`LH:  HasConst = TRUE;
`LHU:  HasConst = TRUE;
`LW:  HasConst = TRUE;
`SB:  HasConst = TRUE;
`SH:  HasConst = TRUE;
`SW:  HasConst = TRUE;
`JAL:   HasConst = TRUE;
`CALL:  HasConst = TRUE;
`RET:   HasConst = TRUE;
default:    HasConst = FALSE;
endcase
endfunction

function IsImmp;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`IMML:  IsImmp = TRUE;
`IMMM:  IsImmp = TRUE;
default: IsImmp = FALSE;
endcase
endfunction

function [0:0] IsMem;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `PUSH:  IsMem = TRUE;
    `POP:   IsMem = TRUE;
    `LBX:   IsMem = TRUE;
    `LHX:   IsMem = TRUE;
    `LHUX:  IsMem = TRUE;
    `LWX:   IsMem = TRUE;
    `SBX:   IsMem = TRUE;
    `SHX:   IsMem = TRUE;
    `SWX:   IsMem = TRUE;
    default: IsMem = FALSE;
    endcase
`LB:    IsMem = TRUE;
`LH:    IsMem = TRUE;
`LHU:   IsMem = TRUE;
`LW:    IsMem = TRUE;
`SB:    IsMem = TRUE;
`SH:    IsMem = TRUE;
`SW:    IsMem = TRUE;
`CALL:  IsMem = TRUE;
`RET:   IsMem = TRUE;
default:    IsMem = FALSE;
endcase
endfunction

function IsMemNdx;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `LBX:   IsMemNdx = TRUE;
    `LHX:   IsMemNdx = TRUE;
    `LHUX:  IsMemNdx = TRUE;
    `LWX:   IsMemNdx = TRUE;
    `SBX:   IsMemNdx = TRUE;
    `SHX:   IsMemNdx = TRUE;
    `SWX:   IsMemNdx = TRUE;
    default: IsMemNdx = FALSE;
    endcase
default:    IsMemNdx = FALSE;
endcase
endfunction

function IsLoad;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `POP:   IsLoad = TRUE;
    `LBX:   IsLoad = TRUE;
    `LHX:   IsLoad = TRUE;
    `LHUX:  IsLoad = TRUE;
    `LWX:   IsLoad = TRUE;
    default: IsLoad = FALSE;   
    endcase
`LB:    IsLoad = TRUE;
`LH:    IsLoad = TRUE;
`LHU:   IsLoad = TRUE;
`LW:    IsLoad = TRUE;
`RET:   IsLoad = TRUE;
default:    IsLoad = FALSE;
endcase
endfunction

function [2:0] MemSize;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `PUSH,`POP:
            case(isn[`INSTRUCTION_S1])
            5'h01,5'h1F:   MemSize = byt;
            5'h04,5'h1C:   MemSize = tetra;
            5'h08,5'h18:   MemSize = octa;
            default:    MemSize = octa;
            endcase
    `LBX,`SBX:   MemSize = byt;
    `LHX,`SHX:   MemSize = tetra;
    `LHUX:       MemSize = tetra;
    `LWX,`SWX:   MemSize = octa;
    default: MemSize = octa;   
    endcase
`LB,`SB:    MemSize = byt;
`LH,`SH:    MemSize = tetra;
`LHU:       MemSize = tetra;
`LW,`SW:    MemSize = octa;
`RET:       MemSize = octa;
default:    MemSize = octa;
endcase
endfunction

function IsStore;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `PUSH:  IsStore = TRUE;
    `SBX:   IsStore = TRUE;
    `SHX:   IsStore = TRUE;
    `SWX:   IsStore = TRUE;
    default:    IsStore = FALSE;
    endcase
`SB:    IsStore = TRUE;
`SH:    IsStore = TRUE;
`SW:    IsStore = TRUE;
`CALL:  IsStore = TRUE;
default:    IsStore = FALSE;
endcase
endfunction

function IsSWC;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `SWCX:   IsSWC = TRUE;
    default:    IsSWC = FALSE;
    endcase
`SWC:    IsSWC = TRUE;
default:    IsSWC = FALSE;
endcase
endfunction

function IsLWR;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `LWRX:   IsLWR = TRUE;
    default:    IsLWR = FALSE;
    endcase
`LWR:    IsLWR = TRUE;
default:    IsLWR = FALSE;
endcase
endfunction

function IsBranch;
input [31:0] isn;
IsBranch = isn[`INSTRUCTION_OP]==`Bcc;
endfunction

function IsRTI;
input [31:0] isn;
IsRTI = isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_S2]==`RTI;
endfunction

function IsRet;
input [31:0] isn;
IsRet = isn[`INSTRUCTION_OP]==`RET;
endfunction

function IsFlowCtrl;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`BRK:    IsFlowCtrl = TRUE;
`RR:    case(isn[`INSTRUCTION_S2])
        `RTI:   IsFlowCtrl = TRUE;
        default:    IsFlowCtrl = FALSE;
        endcase
`Bcc:   IsFlowCtrl = TRUE;
`JAL:    IsFlowCtrl = TRUE;
`CALL:  IsFlowCtrl = TRUE;
`RET:   IsFlowCtrl = TRUE;
default:    IsFlowCtrl = FALSE;
endcase
endfunction

function IsSync;
input [31:0] isn;
IsSync = (isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_S2]==`SYNC); 
endfunction

function IsMemdb;
input [31:0] isn;
IsMemdb = (isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_S2]==`MEMDB); 
endfunction

function IsMemsb;
input [31:0] isn;
IsMemsb = (isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_S2]==`MEMSB); 
endfunction

function IsSEI;
input [31:0] isn;
IsSEI = (isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_S2]==`SEI); 
endfunction

function IsRFW;
input [31:0] isn;
if (fnRt(isn)==6'd0 && !(isn[`INSTRUCTION_OP]==`RR && isn[`INSTRUCTION_S2]==`PUSH))
    IsRFW = FALSE;
else
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `BITFIELD:  IsRFW = TRUE;
    `ADD:   IsRFW = TRUE;
    `SUB:   IsRFW = TRUE;
    `CMP:   IsRFW = TRUE;
    `CMPU:  IsRFW = TRUE;
    `AND:   IsRFW = TRUE;
    `OR:    IsRFW = TRUE;
    `XOR:   IsRFW = TRUE;
    `MULU:  IsRFW = TRUE;
    `MULSU: IsRFW = TRUE;
    `MUL:   IsRFW = TRUE;
    `DIVU:  IsRFW = TRUE;
    `DIVSU: IsRFW = TRUE;
    `DIV:   IsRFW = TRUE;
    `MODU:  IsRFW = TRUE;
    `MODSU: IsRFW = TRUE;
    `MOD:   IsRFW = TRUE;  
    `PUSH:  IsRFW = TRUE;
    `POP:   IsRFW = TRUE;
    `LBX:   IsRFW = TRUE;
    `LHX:   IsRFW = TRUE;
    `LHUX:  IsRFW = TRUE;
    `LWX:   IsRFW = TRUE;
    `SHL,`SHLI:   IsRFW = TRUE;
    `SHR,`SHRI:   IsRFW = TRUE;
    `ASR,`ASRI:   IsRFW = TRUE;
    default:    IsRFW = FALSE;
    endcase
`ADDI:      IsRFW = TRUE;
`CMPI:      IsRFW = TRUE;
`CMPUI:     IsRFW = TRUE;
`ANDI:      IsRFW = TRUE;
`ORI:       IsRFW = TRUE;
`XORI:      IsRFW = TRUE;
`MULUI:     IsRFW = TRUE;
`MULSUI:    IsRFW = TRUE;
`MULI:      IsRFW = TRUE;
`DIVUI:     IsRFW = TRUE;
`DIVSUI:    IsRFW = TRUE;
`DIVI:      IsRFW = TRUE;
`MODUI:     IsRFW = TRUE;
`MODSUI:    IsRFW = TRUE;
`MOD:       IsRFW = TRUE;
`JAL:       IsRFW = TRUE;
`CALL:      IsRFW = TRUE;  
`RET:       IsRFW = TRUE;  
`LB:        IsRFW = TRUE;
`LH:        IsRFW = TRUE;
`LHU:       IsRFW = TRUE;
`LW:        IsRFW = TRUE;
default:    IsRFW = FALSE;
endcase
endfunction

function IsShifti;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `SHLI:  IsShifti = TRUE;
    `SHRI:  IsShifti = TRUE;
    `ASRI:  IsShifti = TRUE;
    default: IsShifti = FALSE;
    endcase
default: IsShifti = FALSE;
endcase
endfunction

function IsMul;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `MULU,`MULSU,`MUL: IsMul = TRUE;
    endcase
`MULUI,`MULSUI,`MULI:  IsMul = TRUE;
default:    IsMul = FALSE;
endcase
endfunction

function IsDivmod;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `DIVU,`DIVSU,`DIV,`MODU,`MODSU,`MOD: IsDivmod = TRUE;
    endcase
`DIVUI,`DIVSUI,`DIVI,`MODUI,`MODSUI,`MODI:  IsDivmod = TRUE;
default:    IsDivmod = FALSE;
endcase
endfunction

function IsAlu0Only;
input [31:0] isn;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `BITFIELD:  IsAlu0Only = TRUE;
    `ASR,`ASRI: IsAlu0Only = TRUE;
    `SHL,`SHLI: IsAlu0Only = TRUE;
    `SHR,`SHRI: IsAlu0Only = TRUE;
    `LBX,`LHX,`LHUX,`LWX:   IsAlu0Only = TRUE;
    `SBX,`SHX,`SWX: IsAlu0Only = TRUE;
    `MULU,`MULSU,`MUL,
    `DIVU,`DIVSU,`DIV,
    `MODU,`MODSU,`MOD:   IsAlu0Only = TRUE;
    default:    IsAlu0Only = FALSE;
    endcase
`MULUI,`MULSUI,`MULI,
`DIVUI,`DIVSUI,`DIVI,
`MODUI,`MODSUI,`MODI:   IsAlu0Only = TRUE;
`CSRRW: IsAlu0Only = TRUE;
default:    IsAlu0Only = FALSE;
endcase
endfunction

function [7:0] fnSelect;
input [31:0] ins;
input [31:0] adr;
begin
	case(ins[`INSTRUCTION_OP])
	`RR:
	   case(ins[`INSTRUCTION_S2])
       `LBX,`SBX:
           case(adr[2:0])
           3'd0:    fnSelect = 8'h01;
           3'd1:    fnSelect = 8'h02;
           3'd2:    fnSelect = 8'h04;
           3'd3:    fnSelect = 8'h08;
           3'd4:    fnSelect = 8'h10;
           3'd5:    fnSelect = 8'h20;
           3'd6:    fnSelect = 8'h40;
           3'd7:    fnSelect = 8'h80;
           endcase
    	`LHX,`LHUX,`SHX:
           case(adr[2])
           1'b0:    fnSelect = 8'h0F;
           1'b1:    fnSelect = 8'hF0;
           endcase
       `LWX,`SWX,`PUSH,`POP:
           fnSelect = 8'hFF;
       default: fnSelect = 8'h00;
	   endcase
    `LB,`SB:
		case(adr[2:0])
		3'd0:	fnSelect = 8'h01;
		3'd1:	fnSelect = 8'h02;
		3'd2:	fnSelect = 8'h04;
		3'd3:	fnSelect = 8'h08;
		3'd4:	fnSelect = 8'h10;
		3'd5:	fnSelect = 8'h20;
		3'd6:	fnSelect = 8'h40;
		3'd7:	fnSelect = 8'h80;
		endcase
	`LH,`LHU,`SH:
		case(adr[2])
		1'b0:	fnSelect = 8'h0F;
		1'b1:	fnSelect = 8'hF0;
		endcase
	`LW,`SW:   fnSelect = 8'hFF;
    `CALL,`RET:  fnSelect = 8'hFF;
	default:	fnSelect = 8'h00;
	endcase
end
endfunction

function [63:0] fnDati;
input [31:0] ins;
input [31:0] adr;
input [63:0] dat;
case(ins[`INSTRUCTION_OP])
`RR:
    case(ins[`INSTRUCTION_S2])
    `LBX:
        case(adr[2:0])
        3'd0:   fnDati = {{56{dat[7]}},dat[7:0]};
        3'd1:   fnDati = {{56{dat[15]}},dat[15:8]};
        3'd2:   fnDati = {{56{dat[23]}},dat[23:16]};
        3'd3:   fnDati = {{56{dat[31]}},dat[31:24]};
        3'd4:   fnDati = {{56{dat[39]}},dat[39:32]};
        3'd5:   fnDati = {{56{dat[47]}},dat[47:40]};
        3'd6:   fnDati = {{56{dat[55]}},dat[55:48]};
        3'd7:   fnDati = {{56{dat[63]}},dat[63:56]};
        endcase
    `LHX:
        case(adr[2])
        1'b0:   fnDati = {{32{dat[31]}},dat[31:0]};
        1'b1:   fnDati = {{32{dat[63]}},dat[63:32]};
        endcase
    `LHUX:
        case(adr[2])
        1'b0:   fnDati = {{32{1'b0}},dat[31:0]};
        1'b1:   fnDati = {{32{1'b0}},dat[63:32]};
        endcase
    `LWX,`POP:  fnDati = dat;
    default:    fnDati = dat;
    endcase
`LB:
    case(adr[2:0])
    3'd0:   fnDati = {{56{dat[7]}},dat[7:0]};
    3'd1:   fnDati = {{56{dat[15]}},dat[15:8]};
    3'd2:   fnDati = {{56{dat[23]}},dat[23:16]};
    3'd3:   fnDati = {{56{dat[31]}},dat[31:24]};
    3'd4:   fnDati = {{56{dat[39]}},dat[39:32]};
    3'd5:   fnDati = {{56{dat[47]}},dat[47:40]};
    3'd6:   fnDati = {{56{dat[55]}},dat[55:48]};
    3'd7:   fnDati = {{56{dat[63]}},dat[63:56]};
    endcase
`LH:
    case(adr[2])
    1'b0:   fnDati = {{32{dat[31]}},dat[31:0]};
    1'b1:   fnDati = {{32{dat[63]}},dat[63:32]};
    endcase
`LHU:
    case(adr[2])
    1'b0:   fnDati = {{32{1'b0}},dat[31:0]};
    1'b1:   fnDati = {{32{1'b0}},dat[63:32]};
    endcase
`LW,`RET:   fnDati = dat;
default:    fnDati = dat;
endcase
endfunction

function [63:0] fnDato;
input [31:0] isn;
input [63:0] dat;
case(isn[`INSTRUCTION_OP])
`RR:
    case(isn[`INSTRUCTION_S2])
    `SBX:   fnDato = {8{dat[7:0]}};
    `SHX:   fnDato = {2{dat[31:0]}};
    default:    fnDato = dat;
    endcase
`SB:   fnDato = {8{dat[7:0]}};
`SH:   fnDato = {2{dat[31:0]}};
default:    fnDato = dat;
endcase
endfunction

// Indicate if the ALU instruction is valid immediately (single cycle operation)
function IsSingleCycle;
input [31:0] isn;
IsSingleCycle = TRUE;
endfunction

decoder6 iq0(.num(iqentry_tgt[0]), .out(iq0_out));
decoder6 iq1(.num(iqentry_tgt[1]), .out(iq1_out));
decoder6 iq2(.num(iqentry_tgt[2]), .out(iq2_out));
decoder6 iq3(.num(iqentry_tgt[3]), .out(iq3_out));
decoder6 iq4(.num(iqentry_tgt[4]), .out(iq4_out));
decoder6 iq5(.num(iqentry_tgt[5]), .out(iq5_out));
decoder6 iq6(.num(iqentry_tgt[6]), .out(iq6_out));
decoder6 iq7(.num(iqentry_tgt[7]), .out(iq7_out));

//initial begin: stop_at
//#1000000; panic <= `PANIC_OVERRUN;
//end

initial begin: Init
//integer i;

//    for (i=0; i<8192; i=i+1)
//        m[i] = 0;

//	$readmemh("init.dat", m);
	//
	//
	// set up panic messages
	message[ `PANIC_NONE ]			= "NONE            ";
	message[ `PANIC_FETCHBUFBEQ ]		= "FETCHBUFBEQ     ";
	message[ `PANIC_INVALIDISLOT ]		= "INVALIDISLOT    ";
	message[ `PANIC_IDENTICALDRAMS ]	= "IDENTICALDRAMS  ";
	message[ `PANIC_OVERRUN ]		= "OVERRUN         ";
	message[ `PANIC_HALTINSTRUCTION ]	= "HALTINSTRUCTION ";
	message[ `PANIC_INVALIDMEMOP ]		= "INVALIDMEMOP    ";
	message[ `PANIC_INVALIDFBSTATE ]	= "INVALIDFBSTATE  ";
	message[ `PANIC_INVALIDIQSTATE ]	= "INVALIDIQSTATE  ";
	message[ `PANIC_BRANCHBACK ]		= "BRANCHBACK      ";
	message[ `PANIC_MEMORYRACE ]		= "MEMORYRACE      ";

end

// ---------------------------------------------------------------------------
// FETCH
// ---------------------------------------------------------------------------
//
    assign fetchbuf0_instr = (fetchbuf == 1'b0) ? fetchbufA_instr : fetchbufC_instr;
    assign fetchbuf0_v     = (fetchbuf == 1'b0) ? fetchbufA_v     : fetchbufC_v    ;
    assign fetchbuf0_pc    = (fetchbuf == 1'b0) ? fetchbufA_pc    : fetchbufC_pc   ;
    assign fetchbuf1_instr = (fetchbuf == 1'b0) ? fetchbufB_instr : fetchbufD_instr;
    assign fetchbuf1_v     = (fetchbuf == 1'b0) ? fetchbufB_v     : fetchbufD_v    ;
    assign fetchbuf1_pc    = (fetchbuf == 1'b0) ? fetchbufB_pc    : fetchbufD_pc   ;

    assign fetchbuf0_mem   = (fetchbuf == 1'b0) ? IsMem(fetchbufA_instr) : IsMem(fetchbufC_instr);
    assign fetchbuf0_jmp   = (fetchbuf == 1'b0)	? IsFlowCtrl(fetchbufA_instr) : IsFlowCtrl(fetchbufC_instr);
    assign fetchbuf0_rfw   = (fetchbuf == 1'b0) ? IsRFW(fetchbufA_instr) : IsRFW(fetchbufC_instr);

    assign fetchbuf1_mem   = (fetchbuf == 1'b0) ? IsMem(fetchbufB_instr) : IsMem(fetchbufD_instr);
    assign fetchbuf1_jmp   = (fetchbuf == 1'b0)	? IsFlowCtrl(fetchbufB_instr) : IsFlowCtrl(fetchbufD_instr);
    assign fetchbuf1_rfw   = (fetchbuf == 1'b0) ? IsRFW(fetchbufB_instr) : IsRFW(fetchbufD_instr);

    //
    // set branchback and backpc values ... ignore branches in fetchbuf slots not ready for enqueue yet
    //
    wire predict_taken0 = (fetchbuf==1'b0) ? predict_takenA : predict_takenC;
    wire predict_taken1 = (fetchbuf==1'b0) ? predict_takenB : predict_takenD;

    assign backpc = (({fetchbuf0_v, IsBranch(fetchbuf0_instr), predict_taken0} == {`VAL, `TRUE, `TRUE}) 
			    ? (fetchbuf0_pc + 4 + { {16 {fetchbuf0_instr[`INSTRUCTION_SB]}}, fetchbuf0_instr[`INSTRUCTION_IM]})
			    : (fetchbuf1_pc + 4 + { {16 {fetchbuf1_instr[`INSTRUCTION_SB]}}, fetchbuf1_instr[`INSTRUCTION_IM]}));

wire take_branch0 = {fetchbuf0_v, IsBranch(fetchbuf0_instr), predict_taken0}  == {`VAL, `TRUE, `TRUE};
wire take_branch1 = {fetchbuf1_v, IsBranch(fetchbuf1_instr), predict_taken1}  == {`VAL, `TRUE, `TRUE};
assign take_branch = take_branch0 || take_branch1;

assign take_branchA = ({fetchbufA_v, IsBranch(fetchbufA_instr), predict_takenA}  == {`VAL, `TRUE, `TRUE});
assign take_branchB = ({fetchbufB_v, IsBranch(fetchbufB_instr), predict_takenB}  == {`VAL, `TRUE, `TRUE});
assign take_branchC = ({fetchbufC_v, IsBranch(fetchbufC_instr), predict_takenC}  == {`VAL, `TRUE, `TRUE});
assign take_branchD = ({fetchbufD_v, IsBranch(fetchbufD_instr), predict_takenD}  == {`VAL, `TRUE, `TRUE});

wire [31:0] branch_pcA = fetchbufA_pc + {{16{fetchbufA_instr[`INSTRUCTION_SB]}},fetchbufA_instr[31:16]} + 64'd4;
wire [31:0] branch_pcB = fetchbufB_pc + {{16{fetchbufB_instr[`INSTRUCTION_SB]}},fetchbufB_instr[31:16]} + 64'd4;
wire [31:0] branch_pcC = fetchbufC_pc + {{16{fetchbufC_instr[`INSTRUCTION_SB]}},fetchbufC_instr[31:16]} + 64'd4;
wire [31:0] branch_pcD = fetchbufD_pc + {{16{fetchbufD_instr[`INSTRUCTION_SB]}},fetchbufD_instr[31:16]} + 64'd4;

always @*
if (take_branchA) begin
    branch_pc <= fetchbufA_pc + {{16{fetchbufA_instr[`INSTRUCTION_SB]}},fetchbufA_instr[31:16]} + 64'd4;
end
else if (take_branchB) begin
    branch_pc <= fetchbufB_pc + {{16{fetchbufB_instr[`INSTRUCTION_SB]}},fetchbufB_instr[31:16]} + 64'd4;
end
else if (take_branchC) begin
    branch_pc <= fetchbufC_pc + {{16{fetchbufC_instr[`INSTRUCTION_SB]}},fetchbufC_instr[31:16]} + 64'd4;
end
else if (take_branchD) begin
    branch_pc <= fetchbufD_pc + {{16{fetchbufD_instr[`INSTRUCTION_SB]}},fetchbufD_instr[31:16]} + 64'd4;
end
else begin
    branch_pc <= RSTPC;  // set to something to prevent a latch
end

    //
    // BRANCH-MISS LOGIC: livetarget
    //
    // livetarget implies that there is a not-to-be-stomped instruction that targets the register in question
    // therefore, if it is zero it implies the rf_v value should become VALID on a branchmiss
    // 

genvar g;
generate begin : live_target
    for (g = 1; g <= PREGS; g = g + 1)
    assign livetarget[g] = iqentry_0_livetarget[g] |
                        iqentry_1_livetarget[g] |
                        iqentry_2_livetarget[g] |
                        iqentry_3_livetarget[g] |
                        iqentry_4_livetarget[g] |
                        iqentry_5_livetarget[g] |
                        iqentry_6_livetarget[g] |
                        iqentry_7_livetarget[g];

end
endgenerate

    assign  iqentry_0_livetarget = {PREGS {iqentry_v[0]}} & {PREGS {~iqentry_stomp[0]}} & iq0_out,
	    iqentry_1_livetarget = {PREGS {iqentry_v[1]}} & {PREGS {~iqentry_stomp[1]}} & iq1_out,
	    iqentry_2_livetarget = {PREGS {iqentry_v[2]}} & {PREGS {~iqentry_stomp[2]}} & iq2_out,
	    iqentry_3_livetarget = {PREGS {iqentry_v[3]}} & {PREGS {~iqentry_stomp[3]}} & iq3_out,
	    iqentry_4_livetarget = {PREGS {iqentry_v[4]}} & {PREGS {~iqentry_stomp[4]}} & iq4_out,
	    iqentry_5_livetarget = {PREGS {iqentry_v[5]}} & {PREGS {~iqentry_stomp[5]}} & iq5_out,
	    iqentry_6_livetarget = {PREGS {iqentry_v[6]}} & {PREGS {~iqentry_stomp[6]}} & iq6_out,
	    iqentry_7_livetarget = {PREGS {iqentry_v[7]}} & {PREGS {~iqentry_stomp[7]}} & iq7_out;

    //
    // BRANCH-MISS LOGIC: latestID
    //
    // latestID is the instruction queue ID of the newest instruction (latest) that targets
    // a particular register.  looks a lot like scheduling logic, but in reverse.
    // 
    assign iqentry_0_cumulative = (missid==3'd0) ? iqentry_0_livetarget :
                                  (missid==3'd1) ? iqentry_0_livetarget |
                                                   iqentry_1_livetarget :
                                  (missid==3'd2) ? iqentry_0_livetarget |
                                                   iqentry_1_livetarget |
                                                   iqentry_2_livetarget :
                                  (missid==3'd3) ? iqentry_0_livetarget |
                                                   iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget :
                                  (missid==3'd4) ? iqentry_0_livetarget |
                                                   iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget | 
                                                   iqentry_4_livetarget :
                                  (missid==3'd5) ? iqentry_0_livetarget |
                                                   iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget | 
                                                   iqentry_4_livetarget |
                                                   iqentry_5_livetarget :
                                  (missid==3'd6) ? iqentry_0_livetarget |
                                                   iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget | 
                                                   iqentry_4_livetarget |
                                                   iqentry_5_livetarget |
                                                   iqentry_6_livetarget :
                                  (missid==3'd7) ? iqentry_0_livetarget |
                                                   iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget | 
                                                   iqentry_4_livetarget |
                                                   iqentry_5_livetarget |
                                                   iqentry_6_livetarget |
                                                   iqentry_7_livetarget :
                                                   {PREGS{1'b0}};

    assign iqentry_1_cumulative = (missid==3'd1) ? iqentry_1_livetarget :
                                  (missid==3'd2) ? iqentry_1_livetarget |
                                                   iqentry_2_livetarget :
                                  (missid==3'd3) ? iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget :
                                  (missid==3'd4) ? iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget |
                                                   iqentry_4_livetarget :
                                  (missid==3'd5) ? iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget |
                                                   iqentry_4_livetarget | 
                                                   iqentry_5_livetarget :
                                  (missid==3'd6) ? iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget |
                                                   iqentry_4_livetarget | 
                                                   iqentry_5_livetarget |
                                                   iqentry_6_livetarget :
                                  (missid==3'd7) ? iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget |
                                                   iqentry_4_livetarget | 
                                                   iqentry_5_livetarget |
                                                   iqentry_6_livetarget |
                                                   iqentry_7_livetarget :
                                  (missid==3'd0) ? iqentry_1_livetarget |
                                                   iqentry_2_livetarget |
                                                   iqentry_3_livetarget |
                                                   iqentry_4_livetarget | 
                                                   iqentry_5_livetarget |
                                                   iqentry_6_livetarget |
                                                   iqentry_7_livetarget |
                                                   iqentry_0_livetarget :
                                                   {PREGS{1'b0}};

    assign iqentry_2_cumulative = (missid==3'd2) ? iqentry_2_livetarget :
                                     (missid==3'd3) ? iqentry_2_livetarget |
                                                      iqentry_3_livetarget :
                                     (missid==3'd4) ? iqentry_2_livetarget |
                                                      iqentry_3_livetarget |
                                                      iqentry_4_livetarget :
                                     (missid==3'd5) ? iqentry_2_livetarget |
                                                      iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget :
                                     (missid==3'd6) ? iqentry_2_livetarget |
                                                      iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget | 
                                                      iqentry_6_livetarget :
                                     (missid==3'd7) ? iqentry_2_livetarget |
                                                      iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget | 
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget :
                                     (missid==3'd0) ? iqentry_2_livetarget |
                                                      iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget | 
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget :
                                     (missid==3'd1) ? iqentry_2_livetarget |
                                                      iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget | 
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget |
                                                      iqentry_1_livetarget :
                                                      {PREGS{1'b0}};

    assign iqentry_3_cumulative = (missid==3'd3) ? iqentry_3_livetarget :
                                     (missid==3'd4) ? iqentry_3_livetarget |
                                                      iqentry_4_livetarget :
                                     (missid==3'd5) ? iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget :
                                     (missid==3'd6) ? iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget :
                                     (missid==3'd7) ? iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget | 
                                                      iqentry_7_livetarget :
                                     (missid==3'd0) ? iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget | 
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget :
                                     (missid==3'd1) ? iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget | 
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget |
                                                      iqentry_1_livetarget :
                                     (missid==3'd2) ? iqentry_3_livetarget |
                                                      iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget | 
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget |
                                                      iqentry_1_livetarget |
                                                      iqentry_2_livetarget :
                                                      {PREGS{1'b0}};

    assign iqentry_4_cumulative = (missid==3'd4) ? iqentry_4_livetarget :
                                     (missid==3'd5) ? iqentry_4_livetarget |
                                                      iqentry_5_livetarget :
                                     (missid==3'd6) ? iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget :
                                     (missid==3'd7) ? iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget :
                                     (missid==3'd0) ? iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget | 
                                                      iqentry_0_livetarget :
                                     (missid==3'd1) ? iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget | 
                                                      iqentry_0_livetarget |
                                                      iqentry_1_livetarget :
                                     (missid==3'd2) ? iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget | 
                                                      iqentry_0_livetarget |
                                                      iqentry_1_livetarget |
                                                      iqentry_2_livetarget :
                                     (missid==3'd3) ? iqentry_4_livetarget |
                                                      iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget | 
                                                      iqentry_0_livetarget |
                                                      iqentry_1_livetarget |
                                                      iqentry_2_livetarget |
                                                      iqentry_3_livetarget :
                                                      {PREGS{1'b0}};

    assign iqentry_5_cumulative = (missid==3'd5) ? iqentry_5_livetarget :
                                     (missid==3'd6) ? iqentry_5_livetarget |
                                                      iqentry_6_livetarget :
                                     (missid==3'd7) ? iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget :
                                     (missid==3'd0) ? iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget :
                                     (missid==3'd1) ? iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget | 
                                                      iqentry_1_livetarget :
                                     (missid==3'd2) ? iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget | 
                                                      iqentry_1_livetarget |
                                                      iqentry_2_livetarget :
                                     (missid==3'd3) ? iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget | 
                                                      iqentry_1_livetarget |
                                                      iqentry_2_livetarget |
                                                      iqentry_3_livetarget :
                                     (missid==3'd4) ? iqentry_5_livetarget |
                                                      iqentry_6_livetarget |
                                                      iqentry_7_livetarget |
                                                      iqentry_0_livetarget | 
                                                      iqentry_1_livetarget |
                                                      iqentry_2_livetarget |
                                                      iqentry_3_livetarget |
                                                      iqentry_4_livetarget :
                                                      {PREGS{1'b0}};
    assign iqentry_6_cumulative = (missid==3'd6) ? iqentry_6_livetarget :
                                       (missid==3'd7) ? iqentry_6_livetarget |
                                                        iqentry_7_livetarget :
                                       (missid==3'd0) ? iqentry_6_livetarget |
                                                        iqentry_7_livetarget |
                                                        iqentry_0_livetarget :
                                       (missid==3'd1) ? iqentry_6_livetarget |
                                                        iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget :
                                       (missid==3'd2) ? iqentry_6_livetarget |
                                                        iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget | 
                                                        iqentry_2_livetarget :
                                       (missid==3'd3) ? iqentry_6_livetarget |
                                                        iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget | 
                                                        iqentry_2_livetarget |
                                                        iqentry_3_livetarget :
                                       (missid==3'd4) ? iqentry_6_livetarget |
                                                        iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget | 
                                                        iqentry_2_livetarget |
                                                        iqentry_3_livetarget |
                                                        iqentry_4_livetarget :
                                       (missid==3'd5) ? iqentry_6_livetarget |
                                                        iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget | 
                                                        iqentry_2_livetarget |
                                                        iqentry_3_livetarget |
                                                        iqentry_4_livetarget |
                                                        iqentry_5_livetarget :
                                                        {PREGS{1'b0}};

    assign iqentry_7_cumulative = (missid==3'd7) ? iqentry_7_livetarget :
                                       (missid==3'd0) ? iqentry_7_livetarget |
                                                        iqentry_0_livetarget :
                                       (missid==3'd1) ? iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget :
                                       (missid==3'd2) ? iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget |
                                                        iqentry_2_livetarget :
                                       (missid==3'd3) ? iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget |
                                                        iqentry_2_livetarget | 
                                                        iqentry_3_livetarget :
                                       (missid==3'd4) ? iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget |
                                                        iqentry_2_livetarget | 
                                                        iqentry_3_livetarget |
                                                        iqentry_4_livetarget :
                                       (missid==3'd5) ? iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget |
                                                        iqentry_2_livetarget | 
                                                        iqentry_3_livetarget |
                                                        iqentry_4_livetarget |
                                                        iqentry_5_livetarget :
                                       (missid==3'd6) ? iqentry_7_livetarget |
                                                        iqentry_0_livetarget |
                                                        iqentry_1_livetarget |
                                                        iqentry_2_livetarget | 
                                                        iqentry_3_livetarget |
                                                        iqentry_4_livetarget |
                                                        iqentry_5_livetarget |
                                                        iqentry_6_livetarget :
                                                        {PREGS{1'b0}};

    assign iqentry_0_latestID = (missid == 3'd0 || ((iqentry_0_livetarget & iqentry_1_cumulative) == {PREGS{1'b0}}))
				    ? iqentry_0_livetarget
				    : {PREGS{1'b0}};

    assign iqentry_1_latestID = (missid == 3'd1 || ((iqentry_1_livetarget & iqentry_2_cumulative) == {PREGS{1'b0}}))
				    ? iqentry_1_livetarget
				    : {PREGS{1'b0}};

    assign iqentry_2_latestID = (missid == 3'd2 || ((iqentry_2_livetarget & iqentry_3_cumulative) == {PREGS{1'b0}}))
				    ? iqentry_2_livetarget
				    : {PREGS{1'b0}};

    assign iqentry_3_latestID = (missid == 3'd3 || ((iqentry_3_livetarget & iqentry_4_cumulative) == {PREGS{1'b0}}))
				    ? iqentry_3_livetarget
				    : {PREGS{1'b0}};

    assign iqentry_4_latestID = (missid == 3'd4 || ((iqentry_4_livetarget & iqentry_5_cumulative) == {PREGS{1'b0}}))
				    ? iqentry_4_livetarget
				    : {PREGS{1'b0}};

    assign iqentry_5_latestID = (missid == 3'd5 || ((iqentry_5_livetarget & iqentry_6_cumulative) == {PREGS{1'b0}}))
				    ? iqentry_5_livetarget
				    : {PREGS{1'b0}};

    assign iqentry_6_latestID = (missid == 3'd6 || ((iqentry_6_livetarget & iqentry_7_cumulative) == {PREGS{1'b0}}))
				    ? iqentry_6_livetarget
				    : {PREGS{1'b0}};

    assign iqentry_7_latestID = (missid == 3'd7 || ((iqentry_7_livetarget & iqentry_0_cumulative) == {PREGS{1'b0}}))
				    ? iqentry_7_livetarget
				    : {PREGS{1'b0}};

    assign  iqentry_source[0] = | iqentry_0_latestID,
	    iqentry_source[1] = | iqentry_1_latestID,
	    iqentry_source[2] = | iqentry_2_latestID,
	    iqentry_source[3] = | iqentry_3_latestID,
	    iqentry_source[4] = | iqentry_4_latestID,
	    iqentry_source[5] = | iqentry_5_latestID,
	    iqentry_source[6] = | iqentry_6_latestID,
	    iqentry_source[7] = | iqentry_7_latestID;


    assign  iqentry_imm[0] = HasConst(iqentry_instr[0]), 
            iqentry_imm[1] = HasConst(iqentry_instr[1]),
            iqentry_imm[2] = HasConst(iqentry_instr[2]),
            iqentry_imm[3] = HasConst(iqentry_instr[3]),
            iqentry_imm[4] = HasConst(iqentry_instr[4]),
            iqentry_imm[5] = HasConst(iqentry_instr[5]),
            iqentry_imm[6] = HasConst(iqentry_instr[6]),
            iqentry_imm[7] = HasConst(iqentry_instr[7]);


assign Ra0 = fnRa(fetchbuf0_instr);
assign Rb0 = fnRb(fetchbuf0_instr);
assign Rc0 = fnRc(fetchbuf0_instr);
assign Rt0 = fnRt(fetchbuf0_instr);
assign Rt0b = fnRt2(fetchbuf0_instr);
assign Ra1 = fnRa(fetchbuf1_instr);
assign Rb1 = fnRb(fetchbuf1_instr);
assign Rc1 = fnRc(fetchbuf1_instr);
assign Rt1 = fnRt(fetchbuf1_instr);
assign Rt1b = fnRt2(fetchbuf1_instr);

    //
    // additional logic for ISSUE
    //
    // for the moment, we look at ALU-input buffers to allow back-to-back issue of 
    // dependent instructions ... we do not, however, look ahead for DRAM requests 
    // that will become valid in the next cycle.  instead, these have to propagate
    // their results into the IQ entry directly, at which point it becomes issue-able
    //

    // note that, for all intents & purposes, iqentry_done == iqentry_agen ... no need to duplicate

wire [QENTRIES-1:0] args_valid;
wire [QENTRIES-1:0] could_issue;

generate begin : issue_logic
for (g = 0; g < QENTRIES; g = g + 1)
begin
assign args_valid[g] =
		  (iqentry_a1_v[g] 
        || (iqentry_a1_s[g] == alu0_sourceid && alu0_dataready)
        || (iqentry_a1_s[g] == alu1_sourceid && alu1_dataready))
    && (iqentry_a2_v[g] 
        || (iqentry_mem[g] & ~iqentry_agen[g] & ~iqentry_memndx[g])    // a2 needs to be valid for indexed instruction
        || (iqentry_a2_s[g] == alu0_sourceid && alu0_dataready)
        || (iqentry_a2_s[g] == alu1_sourceid && alu1_dataready))
    && (iqentry_a3_v[g] 
        || (iqentry_mem[g] & ~iqentry_agen[g])
        || (iqentry_a3_s[g] == alu0_sourceid && alu0_dataready)
        || (iqentry_a3_s[g] == alu1_sourceid && alu1_dataready))
    ;

assign could_issue[g] = iqentry_v[g] && !iqentry_done[g] && !iqentry_out[g] && args_valid[g] &&
                                 (iqentry_mem[g] ? !iqentry_agen[g] : 1'b1);
end                                 
end
endgenerate

// The (old) simulator didn't handle the asynchronous race loop properly in the 
// original code. It would issue two instructions to the same islot. So the
// issue logic has been re-written to eliminate the asynchronous loop.
// Can't issue to the ALU if it's busy doing a long running operation like a 
// divide.
always @*//(could_issue or head0 or head1 or head2 or head3 or head4 or head5 or head6 or head7)
begin
	iqentry_issue = 8'h00;
	iqentry_islot[0] = 2'b00;
	iqentry_islot[1] = 2'b00;
	iqentry_islot[2] = 2'b00;
	iqentry_islot[3] = 2'b00;
	iqentry_islot[4] = 2'b00;
	iqentry_islot[5] = 2'b00;
	iqentry_islot[6] = 2'b00;
	iqentry_islot[7] = 2'b00;
	// See if we can issue to the first alu.
	if (alu0_idle) begin
    if (could_issue[head0] && !iqentry_fp[head0] && iqentry_alu[head0]) begin
      iqentry_issue[head0] = `TRUE;
      iqentry_islot[head0] = 2'b00;
    end
    else if (could_issue[head1] && !iqentry_fp[head1] && iqentry_alu[head1]
    && !(iqentry_v[head0] && iqentry_sync[head0]))
    begin
      iqentry_issue[head1] = `TRUE;
      iqentry_islot[head1] = 2'b00;
    end
    else if (could_issue[head2] && !iqentry_fp[head2] && iqentry_alu[head2]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    )
    begin
      iqentry_issue[head2] = `TRUE;
      iqentry_islot[head2] = 2'b00;
    end
    else if (could_issue[head3] && !iqentry_fp[head3] && iqentry_alu[head3]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    ) begin
      iqentry_issue[head3] = `TRUE;
      iqentry_islot[head3] = 2'b00;
    end
    else if (could_issue[head4] && !iqentry_fp[head4] && iqentry_alu[head4]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    ) begin
      iqentry_issue[head4] = `TRUE;
      iqentry_islot[head4] = 2'b00;
    end
    else if (could_issue[head5] && !iqentry_fp[head5] && iqentry_alu[head5]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    ) begin
      iqentry_issue[head5] = `TRUE;
      iqentry_islot[head5] = 2'b00;
    end
    else if (could_issue[head6] && !iqentry_fp[head6] && iqentry_alu[head6]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    && !(iqentry_v[head5] && iqentry_sync[head5])
    ) begin
      iqentry_issue[head6] = `TRUE;
      iqentry_islot[head6] = 2'b00;
    end
    else if (could_issue[head7] && !iqentry_fp[head7] && iqentry_alu[head7]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    && !(iqentry_v[head5] && iqentry_sync[head5])
    && !(iqentry_v[head6] && iqentry_sync[head6])
    ) begin
      iqentry_issue[head7] = `TRUE;
      iqentry_islot[head7] = 2'b00;
  	end
	end

  if (alu1_idle) begin
    if (could_issue[head0] && !iqentry_fp[head0] && iqentry_alu[head0]
    && !IsAlu0Only(iqentry_instr[head0])
    && !iqentry_issue[head0]) begin
      iqentry_issue[head0] = `TRUE;
      iqentry_islot[head0] = 2'b01;
    end
    else if (could_issue[head1] && !iqentry_fp[head1] && !iqentry_issue[head1] && iqentry_alu[head1]
    && !IsAlu0Only(iqentry_instr[head1])
    && !(iqentry_v[head0] && iqentry_sync[head0]))
    begin
      iqentry_issue[head1] = `TRUE;
      iqentry_islot[head1] = 2'b01;
    end
    else if (could_issue[head2] && !iqentry_fp[head2] && !iqentry_issue[head2] && iqentry_alu[head2]
    && !IsAlu0Only(iqentry_instr[head2])
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    )
    begin
      iqentry_issue[head2] = `TRUE;
      iqentry_islot[head2] = 2'b01;
    end
    else if (could_issue[head3] && !iqentry_fp[head3] && !iqentry_issue[head3] && iqentry_alu[head3]
    && !IsAlu0Only(iqentry_instr[head3])
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    ) begin
      iqentry_issue[head3] = `TRUE;
      iqentry_islot[head3] = 2'b01;
    end
    else if (could_issue[head4] && !iqentry_fp[head4] && !iqentry_issue[head4] && iqentry_alu[head4]
    && !IsAlu0Only(iqentry_instr[head4])
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    ) begin
      iqentry_issue[head4] = `TRUE;
      iqentry_islot[head4] = 2'b01;
    end
    else if (could_issue[head5] && !iqentry_fp[head5] && !iqentry_issue[head5] && iqentry_alu[head5]
    && !IsAlu0Only(iqentry_instr[head5])
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    ) begin
      iqentry_issue[head5] = `TRUE;
      iqentry_islot[head5] = 2'b01;
    end
    else if (could_issue[head6] & !iqentry_fp[head6] && !iqentry_issue[head6] && iqentry_alu[head6]
    && !IsAlu0Only(iqentry_instr[head6])
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    && !(iqentry_v[head5] && iqentry_sync[head5])
    ) begin
      iqentry_issue[head6] = `TRUE;
      iqentry_islot[head6] = 2'b01;
    end
    else if (could_issue[head7] && !iqentry_fp[head7] && !iqentry_issue[head7] && iqentry_alu[head7]
    && !IsAlu0Only(iqentry_instr[head7])
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    && !(iqentry_v[head5] && iqentry_sync[head5])
    && !(iqentry_v[head6] && iqentry_sync[head6])
    ) begin
      iqentry_issue[head7] = `TRUE;
      iqentry_islot[head7] = 2'b01;
    end
  end
end

always @*//(could_issue or head0 or head1 or head2 or head3 or head4 or head5 or head6 or head7)
begin
	iqentry_fcu_issue = 8'h00;
	// See if we can issue to the first alu.
	if (fcu_idle) begin
    if (could_issue[head0] && iqentry_fc[head0]) begin
      iqentry_fcu_issue[head0] = `TRUE;
    end
    else if (could_issue[head1] && iqentry_fc[head1]
    && !(iqentry_v[head0] && iqentry_sync[head0]))
    begin
      iqentry_fcu_issue[head1] = `TRUE;
    end
    else if (could_issue[head2] && iqentry_fc[head2]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    )
    begin
      iqentry_fcu_issue[head2] = `TRUE;
    end
    else if (could_issue[head3] && iqentry_fc[head3]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    ) begin
      iqentry_fcu_issue[head3] = `TRUE;
    end
    else if (could_issue[head4] && iqentry_fc[head4]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    ) begin
      iqentry_fcu_issue[head4] = `TRUE;
    end
    else if (could_issue[head5] && iqentry_fc[head5]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    ) begin
      iqentry_fcu_issue[head5] = `TRUE;
    end
    else if (could_issue[head6] && iqentry_fc[head6]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    && !(iqentry_v[head5] && iqentry_sync[head5])
    ) begin
      iqentry_fcu_issue[head6] = `TRUE;
    end
    else if (could_issue[head7] && iqentry_fc[head7]
    && !(iqentry_v[head0] && iqentry_sync[head0])
    && !(iqentry_v[head1] && iqentry_sync[head1])
    && !(iqentry_v[head2] && iqentry_sync[head2])
    && !(iqentry_v[head3] && iqentry_sync[head3])
    && !(iqentry_v[head4] && iqentry_sync[head4])
    && !(iqentry_v[head5] && iqentry_sync[head5])
    && !(iqentry_v[head6] && iqentry_sync[head6])
    ) begin
      iqentry_fcu_issue[head7] = `TRUE;
  	end
	end
end

    // 
    // additional logic for handling a branch miss (STOMP logic)
    //
    assign  iqentry_stomp[0] = branchmiss && iqentry_v[0] && head0 != 3'd0 && (missid == 3'd7 || iqentry_stomp[7]),
	    iqentry_stomp[1] = branchmiss && iqentry_v[1] && head0 != 3'd1 && (missid == 3'd0 || iqentry_stomp[0]),
	    iqentry_stomp[2] = branchmiss && iqentry_v[2] && head0 != 3'd2 && (missid == 3'd1 || iqentry_stomp[1]),
	    iqentry_stomp[3] = branchmiss && iqentry_v[3] && head0 != 3'd3 && (missid == 3'd2 || iqentry_stomp[2]),
	    iqentry_stomp[4] = branchmiss && iqentry_v[4] && head0 != 3'd4 && (missid == 3'd3 || iqentry_stomp[3]),
	    iqentry_stomp[5] = branchmiss && iqentry_v[5] && head0 != 3'd5 && (missid == 3'd4 || iqentry_stomp[4]),
	    iqentry_stomp[6] = branchmiss && iqentry_v[6] && head0 != 3'd6 && (missid == 3'd5 || iqentry_stomp[5]),
	    iqentry_stomp[7] = branchmiss && iqentry_v[7] && head0 != 3'd7 && (missid == 3'd6 || iqentry_stomp[6]);


    //
    // EXECUTE
    //
    reg [63:0] csr_r;
    always @*
        read_csr(alu0_instr,csr_r);
    FT64alu #(.BIG(1'b1)) ualu0 (
        .rst(rst),
        .clk(clk),
        .ld(alu0_ld),
        .abort(1'b0),
        .instr(alu0_instr),
        .a(alu0_argA),
        .b(alu0_argB),
        .c(alu0_argC),
        .imm(alu0_argI),
        .pc(alu0_pc),
        .csr(csr_r),
        .o(alu0_bus),
        .ob(alu0b_bus),
        .done(alu0_done),
        .idle(alu0_idle)
    );
    FT64alu #(.BIG(1'b0)) ualu1 (
        .rst(rst),
        .clk(clk),
        .ld(alu1_ld),
        .abort(1'b0),
        .instr(alu1_instr),
        .a(alu1_argA),
        .b(alu1_argB),
        .c(alu1_argC),
        .imm(alu1_argI),
        .pc(alu1_pc),
        .csr(64'd0),
        .o(alu1_bus),
        .ob(alu1b_bus),
        .done(alu1_done),
        .idle(alu1_idle)
    );

    assign  alu0_v = alu0_dataready,
	    alu1_v = alu1_dataready;

    assign  alu0_id = alu0_sourceid,
	    alu1_id = alu1_sourceid;

    assign  fcu_v = fcu_dataready;
    assign  fcu_id = fcu_sourceid;

    always @*
    begin
        fcu_exc <= `FLT_NONE;
        case(fcu_instr[`INSTRUCTION_OP])
        `BRK:   fcu_bus <= fcu_instr[15] ? fcu_pc : fcu_pc + 32'd4;
        `Bcc:
           case(fcu_instr[`INSTRUCTION_COND])
           `BEQZ:  fcu_bus <= fcu_argA==64'd0;
           `BNEZ:  fcu_bus <= fcu_argA!=64'd0;
           `BLTZ:  fcu_bus <= fcu_argA[63];
           `BGEZ:  fcu_bus <= ~fcu_argA[63];
           default:    fcu_bus <= 1'b1;
           endcase
        `JAL:   fcu_bus <= fcu_pc + 32'd4;
        `CALL:  fcu_bus <= fcu_argA - 32'd8;
        `RET:   fcu_bus <= fcu_argA;                // address generation, SP update is done by ALU
        `REX:
            case(ol)
            `OL_USER:   fcu_exc <= `FLT_PRIV;
            default:    fcu_bus <= (im < ~ol) ? tvec[fcu_instr[13:11]] : fcu_pc + 32'd4;
            endcase
        endcase
    end

    assign  fcu_misspc =
        IsRTI(fcu_instr) ? epc :
        (fcu_instr[`INSTRUCTION_OP] == `REX) ? fcu_bus :
        (fcu_instr[`INSTRUCTION_OP] == `BRK) ? {tvec[0][31:8], ol, 5'h0}:
        (fcu_instr[`INSTRUCTION_OP] == `CALL || IsRet(fcu_instr)) ? fcu_argI :
        (fcu_instr[`INSTRUCTION_OP] == `JAL) ? fcu_argA + fcu_argI: (fcu_bt ? fcu_pc + 4 : fcu_pc + 4 + fcu_argI);

    assign  alu0_exc = (alu0_instr[`INSTRUCTION_OP] != `BRK)
			? `EXC_NONE
			: (alu0_argB[`INSTRUCTION_S1] == `SYS_NONE)	? `EXC_NONE
			: (alu0_argB[`INSTRUCTION_S1] == `SYS_CALL)	? alu0_argB[`INSTRUCTION_S2]
			: (alu0_argB[`INSTRUCTION_S1] == `SYS_MFSR)	? `EXC_NONE
			: (alu0_argB[`INSTRUCTION_S1] == `SYS_MTSR)	? `EXC_NONE
			: (alu0_argB[`INSTRUCTION_S1] == `SYS_RFU1)	? `EXC_INVALID
			: (alu0_argB[`INSTRUCTION_S1] == `SYS_RFU2)	? `EXC_INVALID
			: (alu0_argB[`INSTRUCTION_S1] == `SYS_RFU3)	? `EXC_INVALID
			: (alu0_argB[`INSTRUCTION_S1] == `SYS_EXC)	? alu0_argB[`INSTRUCTION_S2]
			: `EXC_INVALID;

    assign  alu1_exc = (alu1_instr[`INSTRUCTION_OP] != `BRK)
			? `EXC_NONE
			: (alu1_argB[`INSTRUCTION_S1] == `SYS_NONE)	? `EXC_NONE
			: (alu1_argB[`INSTRUCTION_S1] == `SYS_CALL)	? alu1_argB[`INSTRUCTION_S2]
			: (alu1_argB[`INSTRUCTION_S1] == `SYS_MFSR)	? `EXC_NONE
			: (alu1_argB[`INSTRUCTION_S1] == `SYS_MTSR)	? `EXC_NONE
			: (alu1_argB[`INSTRUCTION_S1] == `SYS_RFU1)	? `EXC_INVALID
			: (alu1_argB[`INSTRUCTION_S1] == `SYS_RFU2)	? `EXC_INVALID
			: (alu1_argB[`INSTRUCTION_S1] == `SYS_RFU3)	? `EXC_INVALID
			: (alu1_argB[`INSTRUCTION_S1] == `SYS_EXC)	? alu1_argB[`INSTRUCTION_S2]
			: `EXC_INVALID;

    assign fcu_branchmiss = fcu_dataready && 
                (fcu_instr[`INSTRUCTION_OP] == `REX && (im < ~ol)) ||
			   ( IsRTI(fcu_instr) || IsRet(fcu_instr) || (fcu_instr[`INSTRUCTION_OP] == `BRK) || (fcu_instr[`INSTRUCTION_OP] == `CALL) ||
			    (IsBranch(fcu_instr) ? ((|fcu_bus && ~fcu_bt) || (~|fcu_bus && fcu_bt))
			  : (fcu_instr[`INSTRUCTION_OP] == `JAL) ? 1'b1
			  : `INV));

    assign  branchmiss = fcu_branchmiss,
	    misspc = fcu_misspc,
	    missid = fcu_sourceid;

    //
    // additional DRAM-enqueue logic

    assign dram_avail = (dram0 == `DRAMSLOT_AVAIL || dram1 == `DRAMSLOT_AVAIL || dram2 == `DRAMSLOT_AVAIL);

    assign  iqentry_memopsvalid[0] = (iqentry_mem[0] & iqentry_a2_v[0] & iqentry_agen[0]),
	    iqentry_memopsvalid[1] = (iqentry_mem[1] & iqentry_a2_v[1] & iqentry_agen[1]),
	    iqentry_memopsvalid[2] = (iqentry_mem[2] & iqentry_a2_v[2] & iqentry_agen[2]),
	    iqentry_memopsvalid[3] = (iqentry_mem[3] & iqentry_a2_v[3] & iqentry_agen[3]),
	    iqentry_memopsvalid[4] = (iqentry_mem[4] & iqentry_a2_v[4] & iqentry_agen[4]),
	    iqentry_memopsvalid[5] = (iqentry_mem[5] & iqentry_a2_v[5] & iqentry_agen[5]),
	    iqentry_memopsvalid[6] = (iqentry_mem[6] & iqentry_a2_v[6] & iqentry_agen[6]),
	    iqentry_memopsvalid[7] = (iqentry_mem[7] & iqentry_a2_v[7] & iqentry_agen[7]);

    assign  iqentry_memready[0] = (iqentry_v[0] & iqentry_memopsvalid[0] & ~iqentry_memissue[0] & ~iqentry_done[0] & ~iqentry_out[0] & ~iqentry_stomp[0]),
	    iqentry_memready[1] = (iqentry_v[1] & iqentry_memopsvalid[1] & ~iqentry_memissue[1] & ~iqentry_done[1] & ~iqentry_out[1] & ~iqentry_stomp[1]),
	    iqentry_memready[2] = (iqentry_v[2] & iqentry_memopsvalid[2] & ~iqentry_memissue[2] & ~iqentry_done[2] & ~iqentry_out[2] & ~iqentry_stomp[2]),
	    iqentry_memready[3] = (iqentry_v[3] & iqentry_memopsvalid[3] & ~iqentry_memissue[3] & ~iqentry_done[3] & ~iqentry_out[3] & ~iqentry_stomp[3]),
	    iqentry_memready[4] = (iqentry_v[4] & iqentry_memopsvalid[4] & ~iqentry_memissue[4] & ~iqentry_done[4] & ~iqentry_out[4] & ~iqentry_stomp[4]),
	    iqentry_memready[5] = (iqentry_v[5] & iqentry_memopsvalid[5] & ~iqentry_memissue[5] & ~iqentry_done[5] & ~iqentry_out[5] & ~iqentry_stomp[5]),
	    iqentry_memready[6] = (iqentry_v[6] & iqentry_memopsvalid[6] & ~iqentry_memissue[6] & ~iqentry_done[6] & ~iqentry_out[6] & ~iqentry_stomp[6]),
	    iqentry_memready[7] = (iqentry_v[7] & iqentry_memopsvalid[7] & ~iqentry_memissue[7] & ~iqentry_done[7] & ~iqentry_out[7] & ~iqentry_stomp[7]);

    assign outstanding_stores = (dram0 && IsStore(dram0_instr)) ||
                                (dram1 && IsStore(dram1_instr)) ||
                                (dram2 && IsStore(dram2_instr));

    //
    // additional COMMIT logic
    //

always @*
begin
    commit0_v <= ({iqentry_v[head0], iqentry_done[head0]} == 2'b11 && ~|panic);
    commit0_id <= {iqentry_mem[head0], head0};	// if a memory op, it has a DRAM-bus id
    commit0_tgt <= iqentry_tgt[head0];
    commit0_bus <= iqentry_res[head0];
    if (iqentry_tgt2[head0]!=6'd0 && iqentry_v[head0] && iqentry_done[head0]) begin
        commit1_v <= ({iqentry_v[head0], iqentry_done[head0]} == 2'b11 && ~|panic);
        commit1_id <= {iqentry_mem[head0], head0};
        commit1_tgt <= iqentry_tgt2[head0];  
        commit1_bus <= iqentry_res2[head0];
    end
    else begin
        commit1_v <= ({iqentry_v[head0], iqentry_done[head0]} != 2'b10
                   && {iqentry_v[head1], iqentry_done[head1]} == 2'b11 && ~|panic);
        commit1_id <= {iqentry_mem[head1], head1};
        commit1_tgt <= iqentry_tgt[head1];  
        commit1_bus <= iqentry_res[head1];
    end
end
    
    assign int_commit = (commit0_v && iqentry_instr[head0][`INSTRUCTION_OP]==`BRK) ||
                        (commit0_v && commit1_v && iqentry_instr[head1][`INSTRUCTION_OP]==`BRK);

// Check how many instructions can be queued. This might be fewer than the
// number ready to queue from the fetch stage if queue slots aren't
// available or if there are no more physical registers left for remapping.
// The fetch stage needs to know how many instructions will queue so this
// logic is placed here.
// NOPs are filtered out and do not enter the instruction queue. The core
// will stream NOPs on a cache miss and they would mess up the queue order
// if there are immediate prefixes in the queue.
always @*
begin
    queued1 <= FALSE;
    queued2 <= FALSE;
    queuedNop <= FALSE;
    if (!branchmiss) begin
        // Two available
        if (fetchbuf1_v & fetchbuf0_v) begin
            // Is there a pair of NOPs ? (cache miss)
            if ((fetchbuf0_instr[`INSTRUCTION_OP]==`NOP) && (fetchbuf1_instr[`INSTRUCTION_OP]==`NOP))
                queuedNop <= TRUE; 
            else begin
                // If it's a predicted branch queue only the first instruction, the second
                // instruction will be stomped on.
                if (IsBranch(fetchbuf0_instr) && predict_taken0) begin
                    if (iqentry_v[tail0]==`INV)
                        queued1 <= TRUE;
                end
                // This is where a single NOP is allowed through to simplify the code. A
                // single NOP can't be a cache miss. Otherwise it would be necessary to queue
                // fetchbuf1 on tail0 it would add a nightmare to the enqueue code.
                // Not a branch and there are two instructions fetched, see whether or not
                // both instructions can be queued.
                // Note that it could be possible to queue instructions without target
                // registers available if the instruction doesn't target a register.
                // The canq1/canq2 test assumes the instruction needs a target register.
                // This is only a problem when the core runs out of physical target
                // registers, which isn't that often. So the core may rarely stall
                // even though it shouldn't.
                else begin
                    if (iqentry_v[tail0]==`INV) begin
                        queued1 <= TRUE;
                        if (iqentry_v[tail1]==`INV)
                            queued2 <= TRUE;
                    end
                end
            end
        end
        // One available
        else if (fetchbuf0_v) begin
            if (fetchbuf0_instr[`INSTRUCTION_OP]!=`NOP) begin
                if (iqentry_v[tail0]==`INV)
                    queued1 <= TRUE;
            end
            else
                queuedNop <= TRUE;
        end
        else if (fetchbuf1_v) begin
            if (fetchbuf1_instr[`INSTRUCTION_OP]!=`NOP) begin
                if (iqentry_v[tail0]==`INV)
                    queued1 <= TRUE;
            end
            else
                queuedNop <= TRUE;
        end
        //else no instructions available to queue
    end
end

// An attempt to move rf_v to it's own always block.
//reg [31:0] rfv_nxt;

//// Create read ports on the register file valid bit to read out the status
//// before target registers are set invalid during the same cycle.
//task rfv_xx;
//input [5:0] Rn;
//output rfv;
//begin
////    if (branchmiss & ~livetarget[Rn])
////        rfv = TRUE;
////    else if (Rn==commit0_tgt && !rf_v[ commit0_tgt ]) 
////        rfv = rf_source[ commit0_tgt ] == commit0_id || (branchmiss && iqentry_source[ commit0_id[2:0] ]);
////    else if (Rn==commit1_tgt && !rf_v[ commit1_tgt ]) 
////        rfv = rf_source[ commit1_tgt ] == commit1_id || (branchmiss && iqentry_source[ commit1_id[2:0] ]);
////    else
//        rfv = rfv_nxt[Rn];
//end
//endtask

//reg rfv_ra0, rfv_rb0, rfv_rc0;
//reg rfv_ra1, rfv_rb1, rfv_rc1;
//always @*
//begin
//    rfv_xx(Ra0,rfv_ra0);
//    rfv_xx(Rb0,rfv_rb0);
//    rfv_xx(Rc0,rfv_rc0);
//    rfv_xx(Ra1,rfv_ra1);
//    rfv_xx(Rb1,rfv_rb1);
//    rfv_xx(Rc1,rfv_rc1);
//end

//// The rf_v flags use non-blocking assignments so need to be implemented under
//// their own always block. The logic is a little bit less clear but needed for
//// synthesis.
//always @*
//if (rst) begin
//    for (n=0; n<=PREGS; n=n+1) begin
//        rfv_nxt[n] <= 1'b1;
//    end
//end
//else begin
//	if (branchmiss) begin
//        for (n = 1; n <= PREGS; n = n + 1)
//           if (~livetarget[n])
//               rfv_nxt[n] <= `VAL;
//    end
//	if (commit0_v) begin
//        if (!rf_v[ commit0_tgt ]) 
//            rfv_nxt[ commit0_tgt ] <= rf_source[ commit0_tgt ] == commit0_id || (branchmiss && iqentry_source[ commit0_id[2:0] ]);
//        if (commit0_tgt != 6'd0) $display("r%d <- %h   v[%d]<-%d", commit0_tgt, commit0_bus, rf_v[commit0_tgt],
//        rf_source[ commit0_tgt ] == commit0_id || (branchmiss && iqentry_source[ commit0_id[2:0] ]));
//    end
//    if (commit1_v) begin
//        if (!rf_v[ commit1_tgt ]) 
//            rfv_nxt[ commit1_tgt ] <= rf_source[ commit1_tgt ] == commit1_id || (branchmiss && iqentry_source[ commit1_id[2:0] ]);
//        if (commit1_tgt != 6'd0) $display("r%d <- %h   v[%d]<-%d", commit1_tgt, commit1_bus, rf_v[commit1_tgt],
//        rf_source[ commit1_tgt ] == commit1_id || (branchmiss && iqentry_source[ commit1_id[2:0] ]));
//    end
//    rfv_nxt[0] = 1;
//	if (!branchmiss) 	// don't bother doing anything if there's been a branch miss
//        case ({fetchbuf0_v, fetchbuf1_v})
//        2'b00:  ;
//        2'b01:
//            if (queued1) begin
//                if (fetchbuf1_rfw)
//                    rfv_nxt[ Rt1 ] <= `INV;
//            end
//        2'b10:  ;   // Can only happen for branch, which doesn't use regfile
//        2'b11:
//            if (queued1) begin
//                // If it were a branch there'd be no update
//        		if (!(IsBranch(fetchbuf0_instr) && predict_taken0)) begin
//        		    if (queued2) begin
//                        //
//                        // if the two instructions enqueued target the same register, 
//                        // make sure only the second writes to rf_v and rf_source.
//                        // first is allowed to update rf_v and rf_source only if the
//                        // second has no target (BEQ or SW)
//                        //
//                        if (fetchbuf0_rfw)
//                            rfv_nxt[ Rt0 ] <= `INV;
//                        if (fetchbuf1_rfw)
//                            rfv_nxt[ Rt1 ] <= `INV;
//                    end
//                    else begin    // only first instruction was enqueued
//                        if (fetchbuf0_rfw)
//                            rfv_nxt[ Rt0 ] <= `INV;
//                    end
//        		end
//            end
//        endcase
//    rfv_nxt[0] <= 1;
//end

//always @(posedge clk)
//    rf_v <= rfv_nxt;
//
// FETCH
//
// fetch exactly two instructions from memory into the fetch buffer
// unless either one of the buffers is still full, in which case we
// do nothing (kinda like alpha approach)
//
always @(posedge clk)
if (rst) begin
    ol <= 3'd0;
    cpl <= 8'h00;
    im <= 3'd7;
    mstatus <= 64'd0;
    for (n = 0; n < QENTRIES; n = n + 1) begin
        iqentry_v[n] <= 1'b0;
        iqentry_out[n] <= 1'b0;
        iqentry_agen[n] <= 1'b0;
        iqentry_sn[n] <= 8'd0;
    	iqentry_instr[n] <= `NOP_INSN;
    	iqentry_mem[n] <= 1'b0;
    	iqentry_memndx[n] <= FALSE;
        iqentry_memissue[n] <= FALSE;
        iqentry_tgt[n] <= 6'd0;
        iqentry_tgt2[n] <= 6'd0;
        iqentry_a1[n] <= 64'd0;
        iqentry_a2[n] <= 64'd0;
        iqentry_a3[n] <= 64'd0;
        iqentry_a1_v[n] <= `INV;
        iqentry_a2_v[n] <= `INV;
        iqentry_a3_v[n] <= `INV;
        iqentry_a1_s[n] <= 5'd0;
        iqentry_a2_s[n] <= 5'd0;
        iqentry_a3_s[n] <= 5'd0;
    end
    dram0 <= `DRAMSLOT_AVAIL;
    dram1 <= `DRAMSLOT_AVAIL;
    dram2 <= `DRAMSLOT_AVAIL;
    dram0_instr <= `NOP_INSN;
    dram1_instr <= `NOP_INSN;
    dram2_instr <= `NOP_INSN;
    dram0_addr <= 32'h0;
    dram1_addr <= 32'h0;
    dram2_addr <= 32'h0;
	pc0 = RSTPC;
    pc1 = RSTPC + 32'd4;
    L1_adr <= RSTPC;
    fetchbufA_v <= 0;
    fetchbufB_v <= 0;
    fetchbufC_v <= 0;
    fetchbufD_v <= 0;
    head0 <= 0;
    head1 <= 1;
    head2 <= 2;
    head3 <= 3;
    head4 <= 4;
    head5 <= 5;
    head6 <= 6;
    head7 <= 7;
    tail0 <= 0;
    tail1 <= 1;
    panic = `PANIC_NONE;
    alu0_available <= 1;
    alu0_dataready <= 0;
    alu1_available <= 1;
    alu1_dataready <= 0;
    fcu_dataready <= 0;
    fcu_instr <= `NOP_INSN;
    dram_v <= 0;
    fetchbuf <= 0;
    I <= 0;
    icstate <= IDLE;
    bstate <= BIDLE;
    tick <= 64'd0;
    cyc_o <= `LOW;
    stb_o <= `LOW;
    we_o <= `LOW;
    sel_o <= 2'b00;
    sr_o <= `LOW;
    cr_o <= `LOW;
    icl_o <= `LOW;
    pcr <= 32'd0;
    pcr2 <= 64'd0;
    for (n = 0; n < PREGS; n = n + 1)
        rf_v[n] <= `VAL;
end
else begin: fetch_phase
    tick <= tick + 64'd1;
    alu0_ld <= FALSE;
    alu1_ld <= FALSE;

	did_branchback0 <= take_branch0;
	did_branchback1 <= take_branch1;

	if (branchmiss) begin
        for (n = 1; n <= PREGS; n = n + 1)
           if (~livetarget[n])
               rf_v[n] = `VAL;
    end

	if (branchmiss) begin
	    pc0 <= misspc;
	    pc1 <= misspc + 4;
	    fetchbuf <= 1'b0;
	    fetchbufA_v <= `INV;
	    fetchbufB_v <= `INV;
	    fetchbufC_v <= `INV;
	    fetchbufD_v <= `INV;

	    if (|iqentry_0_latestID)	rf_source[ iqentry_tgt[0] ] <= { 1'b0, iqentry_mem[0], 3'd0 };
	    if (|iqentry_1_latestID)	rf_source[ iqentry_tgt[1] ] <= { 1'b0, iqentry_mem[1], 3'd1 };
	    if (|iqentry_2_latestID)	rf_source[ iqentry_tgt[2] ] <= { 1'b0, iqentry_mem[2], 3'd2 };
	    if (|iqentry_3_latestID)	rf_source[ iqentry_tgt[3] ] <= { 1'b0, iqentry_mem[3], 3'd3 };
	    if (|iqentry_4_latestID)	rf_source[ iqentry_tgt[4] ] <= { 1'b0, iqentry_mem[4], 3'd4 };
	    if (|iqentry_5_latestID)	rf_source[ iqentry_tgt[5] ] <= { 1'b0, iqentry_mem[5], 3'd5 };
	    if (|iqentry_6_latestID)	rf_source[ iqentry_tgt[6] ] <= { 1'b0, iqentry_mem[6], 3'd6 };
	    if (|iqentry_7_latestID)	rf_source[ iqentry_tgt[7] ] <= { 1'b0, iqentry_mem[7], 3'd7 };

	    if (|iqentry_0_latestID)	rf_source[ iqentry_tgt2[0] ] <= { 1'b1, iqentry_mem[0], 3'd0 };
	    if (|iqentry_1_latestID)	rf_source[ iqentry_tgt2[1] ] <= { 1'b1, iqentry_mem[1], 3'd1 };
	    if (|iqentry_2_latestID)	rf_source[ iqentry_tgt2[2] ] <= { 1'b1, iqentry_mem[2], 3'd2 };
	    if (|iqentry_3_latestID)	rf_source[ iqentry_tgt2[3] ] <= { 1'b1, iqentry_mem[3], 3'd3 };
	    if (|iqentry_4_latestID)	rf_source[ iqentry_tgt2[4] ] <= { 1'b1, iqentry_mem[4], 3'd4 };
	    if (|iqentry_5_latestID)	rf_source[ iqentry_tgt2[5] ] <= { 1'b1, iqentry_mem[5], 3'd5 };
	    if (|iqentry_6_latestID)	rf_source[ iqentry_tgt2[6] ] <= { 1'b1, iqentry_mem[6], 3'd6 };
	    if (|iqentry_7_latestID)	rf_source[ iqentry_tgt2[7] ] <= { 1'b1, iqentry_mem[7], 3'd7 };
	end
	// Some of the testing for valid branch conditions has been removed. In real
	// hardware it isn't needed, and just increases the size of the core. It's
	// assumed that the hardware is working.
	else if (take_branch) begin

	    // update the fetchbuf valid bits as well as fetchbuf itself
	    // ... this must be based on which things are backwards branches, how many things
	    // will get enqueued (0, 1, or 2), and how old the instructions are
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, fetchbufC_v, fetchbufD_v})

		4'b0000	: ;	// do nothing
		4'b0001	: panic <= `PANIC_INVALIDFBSTATE;
		4'b0010	: panic <= `PANIC_INVALIDFBSTATE;
		4'b0011	: panic <= `PANIC_INVALIDFBSTATE;	// this looks like it might be screwy fetchbuf logic

		// because the first instruction has been enqueued, 
		// we must have noted this in the previous cycle.
		// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
		// this looks like the following:
		//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
		//   cycle 1 - enqueued fbA, stomped on fbB, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
		4'b0100 :
		    begin
			    FetchCD();
			    fetchbufB_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		4'b0101	: panic <= `PANIC_INVALIDFBSTATE;
		4'b0110	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched an INSTR+BEQ, with fbB holding a branchback
		//   cycle 1 - enqueued fbA, but not fbB, recognized branchback in fbB, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbB, but fetched from backwards target
		//   cycle 3 - where we are now ... update fetchbufB_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b0111 :
			begin
			    fetchbufB_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		// this looks like the following:
		//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
		//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufA_v appropriately
		4'b1000 :
			begin
			    FetchCD();
			    fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		4'b1001	: panic <= `PANIC_INVALIDFBSTATE;
		4'b1010	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched a BEQ+INSTR, with fbA holding a branchback
		//   cycle 1 - stomped on fbB, but could not enqueue fbA, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbA, but fetched from backwards target
		//   cycle 3 - where we are now ... set fetchbufA_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b1011 :
			begin
			    fetchbufA_v <=!(queued1|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		// if fbB has the branchback, can't immediately tell which of the following scenarios it is:
		//   cycle 0 - fetched a pair of instructions, one or both of which is a branchback
		//   cycle 1 - where we are now.  stomp, enqueue, and update pc0/pc1
		// or
		//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
		//   cycle 1 - could not enqueue fbA or fbB, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufX_v appropriately
		// if fbA has the branchback, then it is scenario 1.
		// if fbB has it: if pc0 == fbB_pc, then it is the former scenario, else it is the latter
		4'b1100 : begin
			if (take_branchA) begin
			    // has to be first scenario
			    pc0 <= branch_pcA;
			    pc1 <= branch_pcA + 4;
			    fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbufB_v <= `INV;		// stomp on it
			    if ((queued1|queuedNop))	fetchbuf <= 1'b0;
			end
			else if (take_branchB) begin
			    if (did_branchback0) begin
			    FetchCD();
				fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
				fetchbufB_v <= !(queued2|queuedNop);	// if it can be queued, it will
				fetchbuf <= fetchbuf + (queued2|queuedNop);
			    end
			    else begin
				pc0 <= branch_pcB;
				pc1 <= branch_pcB + 4;
				fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
				fetchbufB_v <= !(queued2|queuedNop);	// if it can be queued, it will
				if ((queued2|queuedNop))	fetchbuf <= 1'b0;
			    end
			end
			else panic <= `PANIC_BRANCHBACK;
		    end

		4'b1101	: panic <= `PANIC_INVALIDFBSTATE;
		4'b1110	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched an INSTR+BEQ, with fbB holding a branchback
		//   cycle 1 - enqueued neither fbA nor fbB, recognized branchback in fbB, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbB, but fetched from backwards target
		//   cycle 3 - where we are now ... update fetchbufX_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b1111 :
			begin
			    fetchbufA_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbufB_v <= !(queued2|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued2|queuedNop);
			end

	    endcase
	    else case ({fetchbufC_v, fetchbufD_v, fetchbufA_v, fetchbufB_v})

		4'b0000	: ; // do nothing
		4'b0001	: panic <= `PANIC_INVALIDFBSTATE;
		4'b0010	: panic <= `PANIC_INVALIDFBSTATE;
		4'b0011	: panic <= `PANIC_INVALIDFBSTATE;	// this looks like it might be screwy fetchbuf logic

		// because the first instruction has been enqueued, 
		// we must have noted this in the previous cycle.
		// therefore, pc0 and pc1 have to have been set appropriately ... so do a regular fetch
		// this looks like the following:
		//   cycle 0 - fetched a INSTR+BEQ, with fbD holding a branchback
		//   cycle 1 - enqueued fbC, stomped on fbD, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufB_v appropriately
		4'b0100 :
			begin
			    FetchAB();
			    fetchbufD_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		4'b0101	: panic <= `PANIC_INVALIDFBSTATE;
		4'b0110	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched an INSTR+BEQ, with fbD holding a branchback
		//   cycle 1 - enqueued fbC, but not fbD, recognized branchback in fbD, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbD, but fetched from backwards target
		//   cycle 3 - where we are now ... update fetchbufD_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b0111 :
			begin
			    fetchbufD_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		// this looks like the following:
		//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
		//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufC_v appropriately
		4'b1000 :
			begin
			    FetchAB();
			    fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		4'b1001	: panic <= `PANIC_INVALIDFBSTATE;
		4'b1010	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched a BEQ+INSTR, with fbC holding a branchback
		//   cycle 1 - stomped on fbD, but could not enqueue fbC, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbC, but fetched from backwards target
		//   cycle 3 - where we are now ... set fetchbufC_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b1011 :
			begin
			    fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued1|queuedNop);
			end

		// if fbD has the branchback, can't immediately tell which of the following scenarios it is:
		//   cycle 0 - fetched a pair of instructions, one or both of which is a branchback
		//   cycle 1 - where we are now.  stomp, enqueue, and update pc0/pc1
		// or
		//   cycle 0 - fetched a INSTR+BEQ, with fbD holding a branchback
		//   cycle 1 - could not enqueue fbC or fbD, stalled fetch + updated pc0/pc1
		//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufX_v appropriately
		// if fbC has the branchback, then it is scenario 1.
		// if fbD has it: if pc0 == fbB_pc, then it is the former scenario, else it is the latter
		4'b1100 : begin
			if (take_branchC) begin
			    // has to be first scenario
			    pc0 <= branch_pcC;
			    pc1 <= branch_pcC + 4;
			    fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbufD_v <= `INV;		// stomp on it
			    if ((queued1|queuedNop))	fetchbuf <= 1'b0;
			end
			else if (take_branchD) begin
			    if (did_branchback1) begin
			    FetchAB();
				fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
				fetchbufD_v <= !(queued2|queuedNop);	// if it can be queued, it will
				fetchbuf <= fetchbuf + (queued2|queuedNop);
			    end
			    else begin
				pc0 <= branch_pcD;
				pc1 <= branch_pcD + 4;
				fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
				fetchbufD_v <= !(queued2|queuedNop);	// if it can be queued, it will
				if ((queued2|queuedNop))	fetchbuf <= 1'b0;
			    end
			end
			else panic <= `PANIC_BRANCHBACK;
		    end

		4'b1101	: panic <= `PANIC_INVALIDFBSTATE;
		4'b1110	: panic <= `PANIC_INVALIDFBSTATE;

		// this looks like the following:
		//   cycle 0 - fetched an INSTR+BEQ, with fbD holding a branchback
		//   cycle 1 - enqueued neither fbC nor fbD, recognized branchback in fbD, stalled fetch + updated pc0/pc1
		//   cycle 2 - still could not enqueue fbD, but fetched from backwards target
		//   cycle 3 - where we are now ... update fetchbufX_v appropriately
		//
		// however -- if there are backwards branches in the latter two slots, it is more complex.
		// simple solution: leave it alone and wait until we are through with the first two slots.
		4'b1111 :
			begin
			    fetchbufC_v <= !(queued1|queuedNop);	// if it can be queued, it will
			    fetchbufD_v <= !(queued2|queuedNop);	// if it can be queued, it will
			    fetchbuf <= fetchbuf + (queued2|queuedNop);
			end
	    endcase

	end // if branchback

	else begin	// there is no branchback in the system
	    //
	    // update fetchbufX_v and fetchbuf ... relatively simple, as
	    // there are no backwards branches in the mix
	    if (fetchbuf == 1'b0) case ({fetchbufA_v, fetchbufB_v, (queued1|queuedNop), (queued2|queuedNop)})
		4'b00_00 : ;	// do nothing
		4'b00_01 : panic <= `PANIC_INVALIDIQSTATE;
		4'b00_10 : ;	// do nothing
		4'b00_11 : ;	// do nothing
		4'b01_00 : ;	// do nothing
		4'b01_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b01_10,
		4'b01_11 : begin	// enqueue fbB and flip fetchbuf
			fetchbufB_v <= `INV;
			fetchbuf <= ~fetchbuf;
		    end

		4'b10_00 : ;	// do nothing
		4'b10_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b10_10,
		4'b10_11 : begin	// enqueue fbA and flip fetchbuf
			fetchbufA_v <= `INV;
			fetchbuf <= ~fetchbuf;
		    end

		4'b11_00 : ;	// do nothing
		4'b11_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b11_10 : begin	// enqueue fbA but leave fetchbuf
			fetchbufA_v <= `INV;
		    end

		4'b11_11 : begin	// enqueue both and flip fetchbuf
			fetchbufA_v <= `INV;
			fetchbufB_v <= `INV;
			fetchbuf <= ~fetchbuf;
		    end
	    endcase
	    else case ({fetchbufC_v, fetchbufD_v, (queued1|queuedNop), (queued2|queuedNop)})
		4'b00_00 : ;	// do nothing
		4'b00_01 : panic <= `PANIC_INVALIDIQSTATE;
		4'b00_10 : ;	// do nothing
		4'b00_11 : ;	// do nothing
		4'b01_00 : ;	// do nothing
		4'b01_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b01_10,
		4'b01_11 : begin	// enqueue fbD and flip fetchbuf
			fetchbufD_v <= `INV;
			fetchbuf <= ~fetchbuf;
		    end

		4'b10_00 : ;	// do nothing
		4'b10_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b10_10,
		4'b10_11 : begin	// enqueue fbC and flip fetchbuf
			fetchbufC_v <= `INV;
			fetchbuf <= ~fetchbuf;
		    end

		4'b11_00 : ;	// do nothing
		4'b11_01 : panic <= `PANIC_INVALIDIQSTATE;

		4'b11_10 : begin	// enqueue fbC but leave fetchbuf
			fetchbufC_v <= `INV;
		    end

		4'b11_11 : begin	// enqueue both and flip fetchbuf
			fetchbufC_v <= `INV;
			fetchbufD_v <= `INV;
			fetchbuf <= ~fetchbuf;
		    end
	    endcase
	    //
	    // get data iff the fetch buffers are empty
	    //
	    if (fetchbufA_v == `INV && fetchbufB_v == `INV) begin
            FetchAB();
            // fetchbuf steering logic correction
            if (fetchbufC_v==`INV && fetchbufD_v==`INV && phit)
                fetchbuf <= 1'b0;
	    end
	    else if (fetchbufC_v == `INV && fetchbufD_v == `INV)
    	    FetchCD();
	end

	if (commit0_v) begin
        if (!rf_v[ commit0_tgt ]) 
            rf_v[ commit0_tgt ] = rf_source[ commit0_tgt ] == commit0_id || (branchmiss && iqentry_source[ commit0_id[2:0] ]);
        if (commit0_tgt != 6'd0) $display("r%d <- %h   v[%d]<-%d", commit0_tgt, commit0_bus, rf_v[commit0_tgt],
        rf_source[ commit0_tgt ] == commit0_id || (branchmiss && iqentry_source[ commit0_id[2:0] ]));
    end
    if (commit1_v) begin
        if (!rf_v[ commit1_tgt ]) 
            rf_v[ commit1_tgt ] = rf_source[ commit1_tgt ] == commit1_id || (branchmiss && iqentry_source[ commit1_id[2:0] ]);
        if (commit1_tgt != 6'd0) $display("r%d <- %h   v[%d]<-%d", commit1_tgt, commit1_bus, rf_v[commit1_tgt],
        rf_source[ commit1_tgt ] == commit1_id || (branchmiss && iqentry_source[ commit1_id[2:0] ]));
    end
    rf_v[0] = 1;
    //
    // ENQUEUE
    //
    // place up to two instructions from the fetch buffer into slots in the IQ.
    //   note: they are placed in-order, and they are expected to be executed
    // 0, 1, or 2 of the fetch buffers may have valid data
    // 0, 1, or 2 slots in the instruction queue may be available.
    // if we notice that one of the instructions in the fetch buffer is a backwards branch,
    // predict it taken (set branchback/backpc and delete any instructions after it in fetchbuf)
    //
//    always @(posedge clk) begin: enqueue_phase

//
	// enqueue fetchbuf0 and fetchbuf1, but only if there is room, 
	// and ignore fetchbuf1 if fetchbuf0 has a backwards branch in it.
	//
	// also, do some instruction-decode ... set the operand_valid bits in the IQ
	// appropriately so that the DATAINCOMING stage does not have to look at the opcode
	//
	if (!branchmiss) 	// don't bother doing anything if there's been a branch miss

	case ({fetchbuf0_v, fetchbuf1_v})

	    2'b00: ; // do nothing

	    2'b01: if (queued1) begin

        iqentry_sn   [tail0]    <=   seq_num;
		iqentry_v    [tail0]    <=   `VAL;
		iqentry_done [tail0]    <=   `INV;
		iqentry_out  [tail0]    <=   `INV;
		iqentry_res  [tail0]    <=   `ZERO;
		iqentry_res2 [tail0]    <=   `ZERO;
		iqentry_instr[tail0]    <=   fetchbuf1_instr; 
		iqentry_bt   [tail0]    <=   (IsBranch(fetchbuf1_instr) && predict_taken1); 
		iqentry_agen [tail0]    <=   `INV;
		// If the previous instruction was a hardware interrupt and this instruction is a hardware interrupt
		// inherit the previous pc.
		if (fetchbuf1_instr[`INSTRUCTION_OP]==`BRK && fetchbuf1_instr[15] &&
		   (iqentry_instr[(tail0-1)&7][`INSTRUCTION_OP]==`BRK && iqentry_instr[(tail0-1)&7][15] && iqentry_v[(tail0-1)&7]))
		  iqentry_pc   [tail0]    <= iqentry_pc[(tail0-1)&7];
		// If this instruction is a hardware interurpt and there's a previous immediate prefix
		// -> inherit the address of the prefix
		else if (fetchbuf1_instr[`INSTRUCTION_OP]==`BRK && fetchbuf1_instr[15])
		  case(IQPrefixes(tail0))
		  2'd1:   iqentry_pc   [tail0] <= iqentry_pc[(tail0-1)&7];
		  2'd2:   iqentry_pc   [tail0] <= iqentry_pc[(tail0-2)&7];
		  default:   iqentry_pc   [tail0] <= fetchbuf1_pc;
		  endcase
		else
	       iqentry_pc   [tail0] <= fetchbuf1_pc;
        iqentry_alu  [tail0]    <=   IsALU(fetchbuf1_instr);
        iqentry_fc   [tail0]    <=   IsFlowCtrl(fetchbuf1_instr);
		iqentry_mem  [tail0]    <=   fetchbuf1_mem;
		iqentry_memndx[tail0]   <=   IsMemNdx(fetchbuf1_instr);
		iqentry_memdb[tail0]    <=   IsMemdb(fetchbuf1_instr);
		iqentry_memsb[tail0]    <=   IsMemsb(fetchbuf1_instr);
		iqentry_jmp  [tail0]    <=   fetchbuf1_jmp;
		iqentry_br   [tail0]    <=   IsBranch(fetchbuf1_instr);
		iqentry_fp   [tail0]    <= FALSE;
		iqentry_sync [tail0]    <=   IsSync(fetchbuf1_instr);
		iqentry_rfw  [tail0]    <=   fetchbuf1_rfw;
		//iqentry_ra   [tail0]    <=   fnRa(fetchbuf1_instr);
		if (fetchbuf1_rfw)
    		iqentry_tgt  [tail0]    <= Rt1;
        else
           iqentry_tgt  [tail0]    <= 6'd0;
        iqentry_tgt2 [tail0]    <=   Rt1b;
		iqentry_exc  [tail0]    <=   `EXC_NONE;
		iqentry_a0   [tail0]    <=   assign_a0(tail0, fetchbuf1_instr);
		iqentry_a1   [tail0]    <=   rfoa1;
		iqentry_a1_v [tail0]    <=   Source1Valid(fetchbuf1_instr) | rf_v[Ra1];
		iqentry_a1_s [tail0]    <=   rf_source [Ra1];
		iqentry_a2   [tail0]    <=    
					      ((fetchbuf1_instr[`INSTRUCTION_OP] == `CALL) ||
					       (fetchbuf1_instr[`INSTRUCTION_OP] == `JAL)
						 ? fetchbuf1_pc + 32'd4: rfob1);
		iqentry_a2_v [tail0]    <=   Source2Valid( fetchbuf1_instr ) | rf_v[Rb1];
		iqentry_a2_s [tail0]    <=  rf_source[ Rb1 ];
		iqentry_a3   [tail0]    <=   rfoc1;
        iqentry_a3_v [tail0]    <=   Source3Valid(fetchbuf1_instr) | rf_v[Rc1];
        iqentry_a3_s [tail0]    <=   rf_source [Rc1];
		tail0 <= tail0 + 1;
		tail1 <= tail1 + 1;
		if (fetchbuf1_rfw) begin
		    rf_source[ Rt1 ] <= { 1'b0, fetchbuf1_mem, tail0 };	// top bit indicates ALU/MEM bus
		    rf_v [Rt1] = `INV;
		    if (Rt1b != 6'd0) begin
		      rf_source[Rt1b] <= { 1'b1, fetchbuf1_mem, tail0 };
		      rf_v[Rt1b] = `INV;
		    end
		end
 
	    end

	    2'b10: if (queued1) begin
//	    $display("queued1: %d", queued1);
//		if (!IsBranch(fetchbuf0_instr))		panic <= `PANIC_FETCHBUFBEQ;
//		if (!predict_taken0)	panic <= `PANIC_FETCHBUFBEQ;
		//
		// this should only happen when the first instruction is a BEQ-backwards and the IQ
		// happened to be full on the previous cycle (thus we deleted fetchbuf1 but did not
		// enqueue fetchbuf0) ... probably no need to check for LW -- sanity check, just in case
		//
    		enque0(tail0);
	   	    tail0 <= tail0 + 1;
		    tail1 <= tail1 + 1;
    		if (fetchbuf0_rfw) begin
                rf_source[ Rt0 ] <= { 1'b0, fetchbuf0_mem, tail0 };    // top bit indicates ALU/MEM bus
                rf_v[Rt0] = `INV;
                if (Rt0b != 6'd0) begin
    	   	        rf_source[Rt0b] <= { 1'b1, fetchbuf0_mem, tail0 };
                    rf_v[Rt0b] = `INV;
                end
            end
	    end

	    2'b11: if (queued1) begin
		//
		// if the first instruction is a backwards branch, enqueue it & stomp on all following instructions
		//
		if (IsBranch(fetchbuf0_instr) && predict_taken0) begin
            enque0(tail0);
		    tail0 <= tail0 + 1;
		    tail1 <= tail1 + 1;
		end

		else begin	// fetchbuf0 doesn't contain a backwards branch
		    //
		    // so -- we can enqueue 1 or 2 instructions, depending on space in the IQ
		    // update tail0/tail1 separately (at top)
		    // update the rf_v and rf_source bits separately (at end)
		    //   the problem is that if we do have two instructions, 
		    //   they may interact with each other, so we have to be
		    //   careful about where things point.
		    //

		    if (queued2) begin
			tail0 <= tail0 + 2;
			tail1 <= tail1 + 2;
		    end
		    else begin    // queued1 will be true
			tail0 <= tail0 + 1;
			tail1 <= tail1 + 1;
		    end
		    //
		    // enqueue the first instruction ...
		    //
            enque0(tail0);
		    //
		    // if there is room for a second instruction, enqueue it
		    //
		    if (queued2) begin

            iqentry_sn   [tail1]    <=  seq_num + 8'd1;
			iqentry_v    [tail1]    <=   `VAL;
			iqentry_done [tail1]    <=   `INV;
			iqentry_out  [tail1]    <=   `INV;
			iqentry_res  [tail1]    <=   `ZERO;
			iqentry_res2 [tail1]    <=   `ZERO;
			iqentry_instr[tail1]    <=   fetchbuf1_instr; 
			iqentry_bt   [tail1]    <=   (IsBranch(fetchbuf1_instr) && predict_taken1); 
			iqentry_agen [tail1]    <=   `INV;
		    // If the previous instruction was a hardware interrupt and this instruction is a hardware interrupt
            // inherit the previous pc.
            if (fetchbuf1_instr[`INSTRUCTION_OP]==`BRK && fetchbuf1_instr[15] &&
                fetchbuf0_instr[`INSTRUCTION_OP]==`BRK && fetchbuf0_instr[15])
              iqentry_pc   [tail1]    <= fetchbuf0_pc;
            // If this instruction is a hardware interurpt and there's a previous immediate prefix
            // -> inherit the address of the prefix
            else if (fetchbuf1_instr[`INSTRUCTION_OP]==`BRK && fetchbuf1_instr[15])
              case({IsImmp(iqentry_instr[(tail0-1)&7]),IsImmp(fetchbuf0_instr)})
              2'd1:   iqentry_pc   [tail1] <= fetchbuf0_pc;
              2'd3:   iqentry_pc   [tail1] <= iqentry_pc[(tail0-1)&7];
              default:   iqentry_pc   [tail1] <= fetchbuf1_pc;
              endcase
            else
               iqentry_pc   [tail1] <= fetchbuf1_pc;
            iqentry_alu  [tail1]    <=   IsALU(fetchbuf1_instr);
            iqentry_fc   [tail1]    <=   IsFlowCtrl(fetchbuf1_instr);
			iqentry_mem  [tail1]    <=   fetchbuf1_mem;
    		iqentry_memndx[tail1]   <=   IsMemNdx(fetchbuf1_instr);
    		iqentry_memdb[tail1]    <=   IsMemdb(fetchbuf1_instr);
            iqentry_memsb[tail1]    <=   IsMemsb(fetchbuf1_instr);
			iqentry_jmp  [tail1]    <=   fetchbuf1_jmp;
    		iqentry_br   [tail1]    <=   IsBranch(fetchbuf1_instr);
    		iqentry_fp   [tail1]    <= FALSE;
    		iqentry_sync [tail1]    <=  IsSync(fetchbuf1_instr);
			iqentry_rfw  [tail1]    <=   fetchbuf1_rfw;
    		//iqentry_ra   [tail1]    <=   fnRa(fetchbuf1_instr);
    		if (fetchbuf1_rfw) begin
                iqentry_tgt  [tail1]    <= Rt1;
            end
            else begin
               iqentry_tgt  [tail1]    <= 6'd0;
            end
            iqentry_tgt2 [tail1]    <= Rt1b;
			iqentry_exc  [tail1]    <=   `EXC_NONE;
			if (IsShifti(fetchbuf1_instr)||IsSEI(fetchbuf1_instr))
			    iqentry_a0[tail1] <= {58'd0,fetchbuf1_instr[21],fetchbuf1_instr[`INSTRUCTION_RB]};
	        else if (fetchbuf0_instr[`INSTRUCTION_OP]==`IMML && fetchbuf1_instr[`INSTRUCTION_OP]==`IMMM)
                iqentry_a0[tail1] <= {fetchbuf1_instr[27:6],fetchbuf0_instr[31:6],16'h0000};
            else if (fetchbuf0_instr[`INSTRUCTION_OP]==`IMML)
                iqentry_a0[tail1] <= {{22{fetchbuf0_instr[`INSTRUCTION_SB]}},fetchbuf0_instr[31:6],fetchbuf1_instr[31:16]};
            else if (fetchbuf0_instr[`INSTRUCTION_OP]==`IMMM) begin
                if (iqentry_instr[(tail0-1)&7][`INSTRUCTION_OP]==`IMML)
                    iqentry_a0[tail1] <= {fetchbuf0_instr[27:6],iqentry_a0[(tail0-1)&7][41:16],fetchbuf1_instr[31:16]}; 
                else
                    iqentry_a0[tail1] <= {fetchbuf0_instr[27:6],26'b0,fetchbuf1_instr[31:16]}; 
            end
            else if (fetchbuf1_instr[`INSTRUCTION_OP] == `IMML)
                iqentry_a0[tail1] <= {{22{fetchbuf1_instr[`INSTRUCTION_SB]}},fetchbuf1_instr[31:6],16'h0000}; 
            else if (fetchbuf1_instr[`INSTRUCTION_OP] == `IMMM)
                iqentry_a0[tail1] <= {fetchbuf1_instr[27:6],42'h00000000};
            else if (fetchbuf1_instr[`INSTRUCTION_OP] == `CALL)
                iqentry_a0[tail1] = {{36{fetchbuf1_instr[31]}},fetchbuf1_instr[31:6],2'd0};
            else 
                iqentry_a0[tail1] <= {{48{fetchbuf1_instr[`INSTRUCTION_SB]}},fetchbuf1_instr[31:16]};
		    iqentry_a1[tail1]    <=   rfoa1;
		    iqentry_a2[tail1]    <=   (fetchbuf1_instr[`INSTRUCTION_OP] == `CALL ||
		                               fetchbuf1_instr[`INSTRUCTION_OP] == `JAL) ? fetchbuf1_pc + 32'd4: rfob1;
            iqentry_a3[tail1]   <=  rfoc1;
			// a1/a2_v and a1/a2_s values require a bit of thinking ...

			//
			// SOURCE 1 ... this is relatively straightforward, because all instructions
			// that have a source (i.e. every instruction but LUI) read from RB
			//
			// if the argument is an immediate or not needed, we're done
			if (Source1Valid( fetchbuf1_instr ) == `VAL) begin
			    iqentry_a1_v [tail1] <= `VAL;
			    iqentry_a1_s [tail1] <= 4'd0;
			end
			// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
			else if (~fetchbuf0_rfw) begin
			    iqentry_a1_v [tail1]    <=   rf_v[Ra1];
			    iqentry_a1_s [tail1]    <=   rf_source [Ra1];
			end
			// otherwise, previous instruction does write to RF ... see if overlap
			else if (Ra1 == Rt0) begin
			    // if the previous instruction is a LW, then grab result from memq, not the iq
			    iqentry_a1_v [tail1]    <=   `INV;
			    iqentry_a1_s [tail1]    <=   { 1'b0, fetchbuf0_mem, tail0 };
			end
			else if (Ra1 == Rt0b) begin
                // if the previous instruction is a LW, then grab result from memq, not the iq
                iqentry_a1_v [tail1]    <=   `INV;
                iqentry_a1_s [tail1]    <=   { 1'b1, fetchbuf0_mem, tail0 };
            end
			// if no overlap, get info from rf_v and rf_source
			else begin
			    iqentry_a1_v [tail1]    <=   rf_v[Ra1];
			    iqentry_a1_s [tail1]    <=   rf_source [Ra1];
			end

			//
			// SOURCE 2 ... this is more contorted than the logic for SOURCE 1 because
			// some instructions (NAND and ADD) read from RC and others (SW, BEQ) read from RA
			//
			// if the argument is an immediate or not needed, we're done
			// Source2 is valid for a JAL.
			if (Source2Valid( fetchbuf1_instr ) == `VAL) begin
			    iqentry_a2_v [tail1] <= `VAL;
			    iqentry_a2_s [tail1] <= 4'd0;
			end
			// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
			else if (~fetchbuf0_rfw) begin
			    iqentry_a2_v [tail1] <= rf_v[Rb1];
			    iqentry_a2_s [tail1] <= rf_source[ Rb1 ];
			end
			// otherwise, previous instruction does write to RF ... see if overlap
			else if (Rb1 == Rt0) begin
			    // if the previous instruction is a LW, then grab result from memq, not the iq
			    iqentry_a2_v [tail1]    <=   `INV;
			    iqentry_a2_s [tail1]    <=   { 1'b0, fetchbuf0_mem, tail0 };
			end
			else if (Rb1 == Rt0b) begin
                // if the previous instruction is a LW, then grab result from memq, not the iq
                iqentry_a2_v [tail1]    <=   `INV;
                iqentry_a2_s [tail1]    <=   { 1'b1, fetchbuf0_mem, tail0 };
            end
			// if no overlap, get info from rf_v and rf_source
			else begin
			    iqentry_a2_v [tail1] <= rf_v[Rb1];
			    iqentry_a2_s [tail1] <= rf_source[ Rb1 ];
			end

			// SOURCE 3 ... this is more contorted than the logic for SOURCE 1 because
			// some instructions (NAND and ADD) read from RC and others (SW, BEQ) read from RA
			//
			// if the argument is an immediate or not needed, we're done
			// Source2 is valid for a JAL.
			if (Source3Valid( fetchbuf1_instr ) == `VAL) begin
			    iqentry_a3_v [tail1] <= `VAL;
			    iqentry_a3_s [tail1] <= 4'd0;
			end
			// if previous instruction writes nothing to RF, then get info from rf_v and rf_source
			else if (~fetchbuf0_rfw) begin
			    iqentry_a3_v [tail1] <= rf_v[Rc1];
			    iqentry_a3_s [tail1] <= rf_source[ Rc1 ];
			end
			// otherwise, previous instruction does write to RF ... see if overlap
			else if (Rc1 == Rt0) begin
			    // if the previous instruction is a LW, then grab result from memq, not the iq
			    iqentry_a3_v [tail1]    <=   `INV;
			    iqentry_a3_s [tail1]    <=   { 1'b0, fetchbuf0_mem, tail0 };
			end
			else if (Rc1 == Rt0b) begin
                // if the previous instruction is a LW, then grab result from memq, not the iq
                iqentry_a3_v [tail1]    <=   `INV;
                iqentry_a3_s [tail1]    <=   { 1'b1, fetchbuf0_mem, tail0 };
            end
			// if no overlap, get info from rf_v and rf_source
			else begin
			    iqentry_a3_v [tail1] <= rf_v[Rc1];
			    iqentry_a3_s [tail1] <= rf_source[ Rc1 ];
			end

			//
			// if the two instructions enqueued target the same register, 
			// make sure only the second writes to rf_v and rf_source.
			// first is allowed to update rf_v and rf_source only if the
			// second has no target (BEQ or SW)
			//
			begin
			    if (fetchbuf0_rfw) begin
				    rf_source[ Rt0 ] <= { 1'b0,fetchbuf0_mem, tail0 };
				    rf_v [ Rt0] = `INV;
				    if (Rt0b!=6'd0) begin
    				    rf_source[ Rt0b ] <= { 1'b1,fetchbuf0_mem, tail0 };
                        rf_v [ Rt0b] = `INV;
				    end
			    end
			    if (fetchbuf1_rfw) begin
				    rf_source[ Rt1 ] <= { 1'b0,fetchbuf1_mem, tail1 };
				    rf_v [ Rt1 ] = `INV;
				    if (Rt1b != 6'd0) begin
    				    rf_source[ Rt1b ] <= { 1'b1,fetchbuf1_mem, tail1 };
                        rf_v [ Rt1b ] = `INV;
				    end
			    end
			end

		    end	// ends the "if IQ[tail1] is available" clause
		    else begin	// only first instruction was enqueued
			if (queued1 & fetchbuf0_rfw) begin
			    rf_source[ Rt0 ] <= {1'b0,fetchbuf0_mem, tail0};
			    rf_v [ Rt0 ] = `INV;
			    if (Rt0b != 6'd0) begin
    			    rf_source[ Rt0b ] <= {1'b1,fetchbuf0_mem, tail0};
                    rf_v [ Rt0b ] = `INV;
			    end
			end
		    end

		end	// ends the "else fetchbuf0 doesn't have a backwards branch" clause
	    end
	endcase
	// On a branchmiss the rename map is set back to the last valid map.
	else begin	// if branchmiss
	    if (iqentry_stomp[0] & ~iqentry_stomp[7]) begin
		tail0 <= 0;
		tail1 <= 1;
	    end
	    else if (iqentry_stomp[1] & ~iqentry_stomp[0]) begin
		tail0 <= 1;
		tail1 <= 2;
	    end
	    else if (iqentry_stomp[2] & ~iqentry_stomp[1]) begin
		tail0 <= 2;
		tail1 <= 3;
	    end
	    else if (iqentry_stomp[3] & ~iqentry_stomp[2]) begin
		tail0 <= 3;
		tail1 <= 4;
	    end
	    else if (iqentry_stomp[4] & ~iqentry_stomp[3]) begin
		tail0 <= 4;
		tail1 <= 5;
	    end
	    else if (iqentry_stomp[5] & ~iqentry_stomp[4]) begin
		tail0 <= 5;
		tail1 <= 6;
	    end
	    else if (iqentry_stomp[6] & ~iqentry_stomp[5]) begin
		tail0 <= 6;
		tail1 <= 7;
	    end
	    else if (iqentry_stomp[7] & ~iqentry_stomp[6]) begin
		tail0 <= 7;
		tail1 <= 0;
	    end
	    // otherwise, it is the last instruction in the queue that has been mispredicted ... do nothing
	end

    //
    // DATAINCOMING
    //
    // wait for operand/s to appear on alu busses and puts them into 
    // the iqentry_a1 and iqentry_a2 slots (if appropriate)
    // as well as the appropriate iqentry_res slots (and setting valid bits)
    //
//    always @(posedge clk) begin: dataincoming_phase
	//
	// put results into the appropriate instruction entries
	//
    // This chunk of code has to be before the enqueue stage so that the agen bit
    // can be reset to zero by enqueue.
    // put results into the appropriate instruction entries
    //
    if (IsMul(alu0_instr)|IsDivmod(alu0_instr)) begin
        if (alu0_done) begin
            alu0_dataready <= `TRUE;
        end
    end

	if (alu0_v) begin
	   if (|alu0_exc)
	       set_exception(alu0_id,alu0_exc);
	    else begin
            iqentry_res	[ alu0_id[2:0] ] <= alu0_bus;
            iqentry_res2[ alu0_id[2:0] ] <= alu0b_bus;
            iqentry_exc	[ alu0_id[2:0] ] <= alu0_exc;
            iqentry_done[ alu0_id[2:0] ] <= !iqentry_mem[ alu0_id[2:0] ] && alu0_done && !IsImmp(alu0_instr);
            iqentry_out	[ alu0_id[2:0] ] <= `INV;
            iqentry_agen[ alu0_id[2:0] ] <= !iqentry_fc[alu0_id[2:0]] || IsRet(alu0_instr);  // RET
            alu0_dataready <= FALSE;
	    end
	end
	if (alu1_v) begin
	    if (|alu1_exc)
	       set_exception(alu1_id,alu1_exc);
	    else begin
            iqentry_res	[ alu1_id[2:0] ] <= alu1_bus;
            iqentry_res2[ alu1_id[2:0] ] <= alu1b_bus;
            iqentry_exc	[ alu1_id[2:0] ] <= alu1_exc;
            iqentry_done[ alu1_id[2:0] ] <= !iqentry_mem[ alu1_id[2:0] ] && alu1_done && !IsImmp(alu1_instr);
            iqentry_out	[ alu1_id[2:0] ] <= `INV;
            iqentry_agen[ alu1_id[2:0] ] <= !iqentry_fc[alu1_id[2:0]] || IsRet(alu1_instr);  // RET
    	    alu1_dataready <= FALSE;
	    end
	end
	if (fcu_v) begin
	    if (|fcu_exc)
	       set_exception(fcu_id,fcu_exc);
	    else begin
            iqentry_res	[ fcu_id[2:0] ] <= fcu_bus;
            iqentry_res2[ fcu_id[2:0] ] <= fcu_bus;
            iqentry_exc    [ fcu_id[2:0] ] <= fcu_exc;
            iqentry_done[ fcu_id[2:0] ] <= !iqentry_mem[ fcu_id[2:0] ] && !IsImmp(fcu_instr); // CALL instruction is also mem
            iqentry_out    [ fcu_id[2:0] ] <= `INV;
            iqentry_agen[ fcu_id[2:0] ] <= !IsRet(fcu_instr);
            fcu_dataready <= !iqentry_mem[ fcu_id[2:0] ];
            fcu_instr <= `NOP_INSN; // to clear branchmiss
        end
	end
	if (dram_v && iqentry_v[ dram_id[2:0] ] && iqentry_mem[ dram_id[2:0] ] ) begin	// if data for stomped instruction, ignore
	    // Must swap the busses around for the RET instruction which targets the PC
	    // register. The queue result is holding the updated SP register. 
	    if (dram_tgtpc) begin
	       fcu_argI <= dram_bus;
	       fcu_dataready <= TRUE;
	    end
	    else
	       iqentry_res	[ dram_id[2:0] ] <= dram_bus;
	    iqentry_exc	[ dram_id[2:0] ] <= dram_exc;
	    iqentry_done[ dram_id[2:0] ] <= `VAL;
	end

	//
	// set the IQ entry == DONE as soon as the SW is let loose to the memory system
	//
	if (dram0 == 2'd1 && IsStore(dram0_instr)) begin
	    if ((alu0_v && (dram0_id[2:0] == alu0_id[2:0])) || (alu1_v && (dram0_id[2:0] == alu1_id[2:0])))	panic <= `PANIC_MEMORYRACE;
//	    iqentry_done[ dram0_id[2:0] ] <= `VAL;
//	    iqentry_out[ dram0_id[2:0] ] <= `INV;
	end
	if (dram1 == 2'd1 && IsStore(dram1_instr)) begin
	    if ((alu0_v && (dram1_id[2:0] == alu0_id[2:0])) || (alu1_v && (dram1_id[2:0] == alu1_id[2:0])))	panic <= `PANIC_MEMORYRACE;
//	    iqentry_done[ dram1_id[2:0] ] <= `VAL;
//	    iqentry_out[ dram1_id[2:0] ] <= `INV;
	end
	if (dram2 == 2'd1 && IsStore(dram2_instr)) begin
	    if ((alu0_v && (dram2_id[2:0] == alu0_id[2:0])) || (alu1_v && (dram2_id[2:0] == alu1_id[2:0])))	panic <= `PANIC_MEMORYRACE;
//	    iqentry_done[ dram2_id[2:0] ] <= `VAL;
//	    iqentry_out[ dram2_id[2:0] ] <= `INV;
	end

	//
	// see if anybody else wants the results ... look at lots of buses:
	//  - alu0_bus
	//  - alu1_bus
	//  - dram_bus
	//  - commit0_bus
	//  - commit1_bus
	//

    for (n = 0; n < QENTRIES; n = n + 1)
    begin
        if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == {1'b0,alu0_id} && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
            iqentry_a1[n] <= alu0_bus;
            iqentry_a1_v[n] <= `VAL;
        end
        if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == {1'b0,alu0_id} && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
            iqentry_a2[n] <= alu0_bus;
            iqentry_a2_v[n] <= `VAL;
        end
        if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == {1'b0,alu0_id} && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
            iqentry_a3[n] <= alu0_bus;
            iqentry_a3_v[n] <= `VAL;
        end
        if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == {1'b0,alu1_id} && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a1[n] <= alu1_bus;
            iqentry_a1_v[n] <= `VAL;
        end
        if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == {1'b0,alu1_id} && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a2[n] <= alu1_bus;
            iqentry_a2_v[n] <= `VAL;
        end
        if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == {1'b0,alu1_id} && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a3[n] <= alu1_bus;
            iqentry_a3_v[n] <= `VAL;
        end
        if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == {1'b1,alu0_id} && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
            iqentry_a1[n] <= alu0b_bus;
            iqentry_a1_v[n] <= `VAL;
        end
        if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == {1'b1,alu0_id} && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
            iqentry_a2[n] <= alu0b_bus;
            iqentry_a2_v[n] <= `VAL;
        end
        if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == {1'b1,alu0_id} && iqentry_v[n] == `VAL && alu0_v == `VAL) begin
            iqentry_a3[n] <= alu0b_bus;
            iqentry_a3_v[n] <= `VAL;
        end
        if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == {1'b1,alu1_id} && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a1[n] <= alu1b_bus;
            iqentry_a1_v[n] <= `VAL;
        end
        if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == {1'b1,alu1_id} && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a2[n] <= alu1b_bus;
            iqentry_a2_v[n] <= `VAL;
        end
        if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == {1'b1,alu1_id} && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a3[n] <= alu1b_bus;
            iqentry_a3_v[n] <= `VAL;
        end
        if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == fcu_id && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a1[n] <= fcu_bus;
            iqentry_a1_v[n] <= `VAL;
        end
        if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == fcu_id && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a2[n] <= fcu_bus;
            iqentry_a2_v[n] <= `VAL;
        end
        if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == fcu_id && iqentry_v[n] == `VAL && alu1_v == `VAL) begin
            iqentry_a3[n] <= fcu_bus;
            iqentry_a3_v[n] <= `VAL;
        end
        if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == dram_id && !dram_tgtpc && iqentry_v[n] == `VAL && dram_v == `VAL) begin
            iqentry_a1[n] <= dram_bus;
            iqentry_a1_v[n] <= `VAL;
        end
        if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == dram_id && !dram_tgtpc && iqentry_v[n] == `VAL && dram_v == `VAL) begin
            iqentry_a2[n] <= dram_bus;
            iqentry_a2_v[n] <= `VAL;
        end
        if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == dram_id && !dram_tgtpc && iqentry_v[n] == `VAL && dram_v == `VAL) begin
            iqentry_a3[n] <= dram_bus;
            iqentry_a3_v[n] <= `VAL;
        end
        if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == commit0_id && iqentry_v[n] == `VAL && commit0_v == `VAL) begin
            iqentry_a1[n] <= commit0_bus;
            iqentry_a1_v[n] <= `VAL;
        end
        if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == commit0_id && iqentry_v[n] == `VAL && commit0_v == `VAL) begin
            iqentry_a2[n] <= commit0_bus;
            iqentry_a2_v[n] <= `VAL;
        end
        if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == commit0_id && iqentry_v[n] == `VAL && commit0_v == `VAL) begin
            iqentry_a3[n] <= commit0_bus;
            iqentry_a3_v[n] <= `VAL;
        end
        if (iqentry_a1_v[n] == `INV && iqentry_a1_s[n] == commit1_id && iqentry_v[n] == `VAL && commit1_v == `VAL) begin
            iqentry_a1[n] <= commit1_bus;
            iqentry_a1_v[n] <= `VAL;
        end
        if (iqentry_a2_v[n] == `INV && iqentry_a2_s[n] == commit1_id && iqentry_v[n] == `VAL && commit1_v == `VAL) begin
            iqentry_a2[n] <= commit1_bus;
            iqentry_a2_v[n] <= `VAL;
        end
        if (iqentry_a3_v[n] == `INV && iqentry_a3_s[n] == commit1_id && iqentry_v[n] == `VAL && commit1_v == `VAL) begin
            iqentry_a3[n] <= commit1_bus;
            iqentry_a3_v[n] <= `VAL;
        end
	end

    //
    // ISSUE 
    //
    // determines what instructions are ready to go, then places them
    // in the various ALU queues.  
    // also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
    //
//    always @(posedge clk) begin: issue_phase

    for (n = 0; n < QENTRIES; n = n + 1)
        if (iqentry_issue[n] && !(iqentry_v[n] && iqentry_stomp[n])) begin
            case (iqentry_islot[n]) 
            2'd0: if (alu0_available & alu0_done) begin
                alu0_sourceid	<= n[3:0];
                alu0_instr	<= iqentry_instr[n];
                alu0_bt		<= iqentry_bt[n];
                alu0_pc		<= iqentry_pc[n];
                alu0_argA	<= iqentry_a1_v[n] ? iqentry_a1[n]
                            : (iqentry_a1_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a1_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}};
                alu0_argB	<= iqentry_imm[n]
                            ? iqentry_a0[n]
                            : (iqentry_a2_v[n] ? iqentry_a2[n]
                            : (iqentry_a2_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a2_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}});
                alu0_argC	<= iqentry_a3_v[n] ? iqentry_a3[n]
                            : (iqentry_a3_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a3_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}};
                alu0_argI	<= iqentry_a0[n];
                alu0_dataready <= IsSingleCycle(iqentry_instr[n]);
                alu0_ld <= TRUE;
                iqentry_out[n] <= `VAL;
                // if it is a memory operation, this is the address-generation step ... collect result into arg1
                if (iqentry_mem[n]) begin
                iqentry_a1_v[n] <= `INV;
                iqentry_a1_s[n] <= n[3:0];
                end
                end
            2'd1: if (alu1_available && alu1_done && !IsAlu0Only(iqentry_instr[n])) begin
                alu1_sourceid	<= n[3:0];
                alu1_instr	<= iqentry_instr[n];
                alu1_bt		<= iqentry_bt[n];
                alu1_pc		<= iqentry_pc[n];
                alu1_argA	<= iqentry_a1_v[n] ? iqentry_a1[n]
                            : (iqentry_a1_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a1_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}};
                alu1_argB	<= iqentry_imm[n]
                            ? iqentry_a0[n]
                            : (iqentry_a2_v[n] ? iqentry_a2[n]
                            : (iqentry_a2_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a2_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}});
                alu1_argC	<= iqentry_a3_v[n] ? iqentry_a3[n]
                            : (iqentry_a3_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a3_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}};
                alu1_argI	<= iqentry_a0[n];
                alu1_dataready <= IsSingleCycle(iqentry_instr[n]);
                alu1_ld <= TRUE;
                iqentry_out[n] <= `VAL;
                // if it is a memory operation, this is the address-generation step ... collect result into arg1
                if (iqentry_mem[n]) begin
                iqentry_a1_v[n] <= `INV;
                iqentry_a1_s[n] <= n[3:0];
                end
                end
            default: panic <= `PANIC_INVALIDISLOT;
            endcase
        end

    for (n = 0; n < QENTRIES; n = n + 1)
        if (iqentry_fcu_issue[n] && !(iqentry_v[n] && iqentry_stomp[n])) begin
            if (fcu_done) begin
                fcu_sourceid	<= n[3:0];
                fcu_instr	<= iqentry_instr[n];
                fcu_bt		<= iqentry_bt[n];
                fcu_pc		<= iqentry_pc[n];
                fcu_argA	<= iqentry_a1_v[n] ? iqentry_a1[n]
                            : (iqentry_a1_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a1_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}};
                fcu_argB	<= iqentry_imm[n]
                            ? iqentry_a0[n]
                            : (iqentry_a2_v[n] ? iqentry_a2[n]
                            : (iqentry_a2_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a2_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}});
                fcu_argC	<= iqentry_a3_v[n] ? iqentry_a3[n]
                            : (iqentry_a3_s[n] == alu0_id) ? alu0_bus
                            : (iqentry_a3_s[n] == alu1_id) ? alu1_bus
                            : {4{16'hDEAD}};
                fcu_argI	<= iqentry_a0[n];
                fcu_dataready <= iqentry_instr[n][`INSTRUCTION_OP]!=`RET;
                iqentry_out[n] <= `VAL;
                // if it is a memory operation, this is the address-generation step ... collect result into arg1
                if (iqentry_mem[n]) begin
                iqentry_a1_v[n] <= `INV;
                iqentry_a1_s[n] <= n[3:0];
                end
            end
        end
    //
    // MEMORY
    //
    // update the memory queues and put data out on bus if appropriate
    //
//    always @(posedge clk) begin: memory_phase

	//
	// dram0, dram1, dram2 are the "state machines" that keep track
	// of three pipelined DRAM requests.  if any has the value "00", 
	// then it can accept a request (which bumps it up to the value "01"
	// at the end of the cycle).  once it hits the value "11" the request
	// is finished and the dram_bus takes the value.  if it is a store, the 
	// dram_bus value is not used, but the dram_v value along with the
	// dram_id value signals the waiting memq entry that the store is
	// completed and the instruction can commit.
	//

//	if (dram0 != `DRAMSLOT_AVAIL)	dram0 <= dram0 + 2'd1;
//	if (dram1 != `DRAMSLOT_AVAIL)	dram1 <= dram1 + 2'd1;
//	if (dram2 != `DRAMSLOT_AVAIL)	dram2 <= dram2 + 2'd1;

    //
    // grab requests that have finished and put them on the dram_bus
    if (dram0 == `DRAMREQ_READY) begin
        dram0 <= `DRAMSLOT_AVAIL;
        dram_v <= IsLoad(dram0_instr);
        dram_id <= dram0_id;
        dram_tgt <= dram0_tgt;
        dram_tgtpc = dram0_instr[`INSTRUCTION_OP]==`RET;
        dram_exc <= dram0_exc;
        dram_bus <= fnDati(dram0_instr,dram0_addr,rdat0);
        if (IsStore(dram0_instr)) 	$display("m[%h] <- %h", dram0_addr, dram0_data);
    end
    else if (dram1 == `DRAMREQ_READY) begin
        dram1 <= `DRAMSLOT_AVAIL;
        dram_v <= IsLoad(dram1_instr);
        dram_id <= dram1_id;
        dram_tgt <= dram1_tgt;
        dram_tgtpc = dram1_instr[`INSTRUCTION_OP]==`RET;
        dram_exc <= dram1_exc;
        dram_bus <= fnDati(dram1_instr,dram1_addr,rdat1);
        if (IsStore(dram1_instr))     $display("m[%h] <- %h", dram1_addr, dram1_data);
    end
    else if (dram2 == `DRAMREQ_READY) begin
        dram2 <= `DRAMSLOT_AVAIL;
        dram_v <= IsLoad(dram2_instr);
        dram_id <= dram2_id;
        dram_tgt <= dram2_tgt;
        dram_tgtpc = dram2_instr[`INSTRUCTION_OP]==`RET;
        dram_exc <= dram2_exc;
        dram_bus <= fnDati(dram2_instr,dram2_addr,rdat2);
        if (IsStore(dram2_instr))     $display("m[%h] <- %h", dram2_addr, dram2_data);
    end
    else begin
        dram_v <= `INV;
    end

	//
	// determine if the instructions ready to issue can, in fact, issue.
	// "ready" means that the instruction has valid operands but has not gone yet
	iqentry_memissue[ head0 ] <=	iqentry_memready[ head0 ];		// first in line ... go as soon as ready

	iqentry_memissue[ head1 ] <=	~iqentry_stomp[head1] && iqentry_memready[ head1 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head1] != iqentry_a1[head0]))
					// ... and there isn't a barrier
    				&& !(iqentry_v[head0] && iqentry_mem[head0] && iqentry_memdb[head0]) 
                    && !(iqentry_v[head0] && iqentry_memsb[head0]) 
					// ... and, if it is a SW, there is no chance of it being undone
					&& (IsLoad(iqentry_instr[head1]) || !IsFlowCtrl(iqentry_instr[head0]));

	iqentry_memissue[ head2 ] <=	~iqentry_stomp[head2] && iqentry_memready[ head2 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head2] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head2] != iqentry_a1[head1]))
					// ... and there isn't a barrier
    				&& !(iqentry_v[head0] && iqentry_mem[head0] && iqentry_memdb[head0]) 
                    && !(iqentry_v[head0] && iqentry_memsb[head0]) 
    				&& !(iqentry_v[head1] && iqentry_mem[head1] && iqentry_memdb[head1]) 
                    && !(iqentry_v[head1] && iqentry_memsb[head1]) 
					// ... and, if it is a SW, there is no chance of it being undone
					&& (IsLoad(iqentry_instr[head2]) ||
					    (  !IsFlowCtrl(iqentry_instr[head0]) &&
					       !IsFlowCtrl(iqentry_instr[head1])));
					        
	iqentry_memissue[ head3 ] <=	~iqentry_stomp[head3] && iqentry_memready[ head3 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head3] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head3] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head3] != iqentry_a1[head2]))
					// ... and there isn't a barrier
    				&& !(iqentry_v[head0] && iqentry_mem[head0] && iqentry_memdb[head0]) 
                    && !(iqentry_v[head0] && iqentry_memsb[head0]) 
                    && !(iqentry_v[head1] && iqentry_mem[head1] && iqentry_memdb[head1]) 
                    && !(iqentry_v[head1] && iqentry_memsb[head1]) 
                    && !(iqentry_v[head2] && iqentry_mem[head2] && iqentry_memdb[head2]) 
                    && !(iqentry_v[head2] && iqentry_memsb[head2]) 
                    // ... and, if it is a SW, there is no chance of it being undone
					&& (IsLoad(iqentry_instr[head3]) ||
                        (  !IsFlowCtrl(iqentry_instr[head0]) &&
                           !IsFlowCtrl(iqentry_instr[head1]) &&
                           !IsFlowCtrl(iqentry_instr[head2])));

	iqentry_memissue[ head4 ] <=	~iqentry_stomp[head4] && iqentry_memready[ head4 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head4] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head4] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head4] != iqentry_a1[head2]))
					&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
						|| (iqentry_a1_v[head3] && iqentry_a1[head4] != iqentry_a1[head3]))
					// ... and there isn't a barrier
    				&& !(iqentry_v[head0] && iqentry_mem[head0] && iqentry_memdb[head0]) 
                    && !(iqentry_v[head0] && iqentry_memsb[head0]) 
                    && !(iqentry_v[head1] && iqentry_mem[head1] && iqentry_memdb[head1]) 
                    && !(iqentry_v[head1] && iqentry_memsb[head1]) 
                    && !(iqentry_v[head2] && iqentry_mem[head2] && iqentry_memdb[head2]) 
                    && !(iqentry_v[head2] && iqentry_memsb[head2]) 
                    && !(iqentry_v[head3] && iqentry_mem[head3] && iqentry_memdb[head3]) 
                    && !(iqentry_v[head3] && iqentry_memsb[head3]) 
					// ... and, if it is a SW, there is no chance of it being undone
					&& (IsLoad(iqentry_instr[head4]) ||
                        (  !IsFlowCtrl(iqentry_instr[head0]) &&
                           !IsFlowCtrl(iqentry_instr[head1]) &&
                           !IsFlowCtrl(iqentry_instr[head2]) &&
                           !IsFlowCtrl(iqentry_instr[head3])));

	iqentry_memissue[ head5 ] <=	~iqentry_stomp[head5] && iqentry_memready[ head5 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head5] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head5] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head5] != iqentry_a1[head2]))
					&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
						|| (iqentry_a1_v[head3] && iqentry_a1[head5] != iqentry_a1[head3]))
					&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
						|| (iqentry_a1_v[head4] && iqentry_a1[head5] != iqentry_a1[head4]))
					// ... and there isn't a barrier
    				&& !(iqentry_v[head0] && iqentry_mem[head0] && iqentry_memdb[head0]) 
                    && !(iqentry_v[head0] && iqentry_memsb[head0]) 
                    && !(iqentry_v[head1] && iqentry_mem[head1] && iqentry_memdb[head1]) 
                    && !(iqentry_v[head1] && iqentry_memsb[head1]) 
                    && !(iqentry_v[head2] && iqentry_mem[head2] && iqentry_memdb[head2]) 
                    && !(iqentry_v[head2] && iqentry_memsb[head2]) 
                    && !(iqentry_v[head3] && iqentry_mem[head3] && iqentry_memdb[head3]) 
                    && !(iqentry_v[head3] && iqentry_memsb[head3]) 
                    && !(iqentry_v[head4] && iqentry_mem[head4] && iqentry_memdb[head4]) 
                    && !(iqentry_v[head4] && iqentry_memsb[head4]) 
					// ... and, if it is a SW, there is no chance of it being undone
					&& (IsLoad(iqentry_instr[head5]) ||
                        (  !IsFlowCtrl(iqentry_instr[head0]) &&
                           !IsFlowCtrl(iqentry_instr[head1]) &&
                           !IsFlowCtrl(iqentry_instr[head2]) &&
                           !IsFlowCtrl(iqentry_instr[head3]) &&
                           !IsFlowCtrl(iqentry_instr[head4])));

	iqentry_memissue[ head6 ] <=	~iqentry_stomp[head6] && iqentry_memready[ head6 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					&& ~iqentry_memready[head5] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head6] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head6] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head6] != iqentry_a1[head2]))
					&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
						|| (iqentry_a1_v[head3] && iqentry_a1[head6] != iqentry_a1[head3]))
					&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
						|| (iqentry_a1_v[head4] && iqentry_a1[head6] != iqentry_a1[head4]))
					&& (!iqentry_mem[head5] || (iqentry_agen[head5] & iqentry_out[head5]) 
						|| (iqentry_a1_v[head5] && iqentry_a1[head6] != iqentry_a1[head5]))
					// ... and there isn't a barrier
    				&& !(iqentry_v[head0] && iqentry_mem[head0] && iqentry_memdb[head0]) 
                    && !(iqentry_v[head0] && iqentry_memsb[head0]) 
                    && !(iqentry_v[head1] && iqentry_mem[head1] && iqentry_memdb[head1]) 
                    && !(iqentry_v[head1] && iqentry_memsb[head1]) 
                    && !(iqentry_v[head2] && iqentry_mem[head2] && iqentry_memdb[head2]) 
                    && !(iqentry_v[head2] && iqentry_memsb[head2]) 
                    && !(iqentry_v[head3] && iqentry_mem[head3] && iqentry_memdb[head3]) 
                    && !(iqentry_v[head3] && iqentry_memsb[head3]) 
                    && !(iqentry_v[head4] && iqentry_mem[head4] && iqentry_memdb[head4]) 
                    && !(iqentry_v[head4] && iqentry_memsb[head4]) 
                    && !(iqentry_v[head5] && iqentry_mem[head5] && iqentry_memdb[head5]) 
                    && !(iqentry_v[head5] && iqentry_memsb[head5]) 
					// ... and, if it is a SW, there is no chance of it being undone
					&& (IsLoad(iqentry_instr[head6]) ||
                        (  !IsFlowCtrl(iqentry_instr[head0]) &&
                           !IsFlowCtrl(iqentry_instr[head1]) &&
                           !IsFlowCtrl(iqentry_instr[head2]) &&
                           !IsFlowCtrl(iqentry_instr[head3]) &&
                           !IsFlowCtrl(iqentry_instr[head4]) &&
                           !IsFlowCtrl(iqentry_instr[head5])));

	iqentry_memissue[ head7 ] <=	~iqentry_stomp[head7] && iqentry_memready[ head7 ]		// addr and data are valid
					// ... and no preceding instruction is ready to go
					&& ~iqentry_memready[head0]
					&& ~iqentry_memready[head1] 
					&& ~iqentry_memready[head2] 
					&& ~iqentry_memready[head3] 
					&& ~iqentry_memready[head4] 
					&& ~iqentry_memready[head5] 
					&& ~iqentry_memready[head6] 
					// ... and there is no address-overlap with any preceding instruction
					&& (!iqentry_mem[head0] || (iqentry_agen[head0] & iqentry_out[head0]) 
						|| (iqentry_a1_v[head0] && iqentry_a1[head7] != iqentry_a1[head0]))
					&& (!iqentry_mem[head1] || (iqentry_agen[head1] & iqentry_out[head1]) 
						|| (iqentry_a1_v[head1] && iqentry_a1[head7] != iqentry_a1[head1]))
					&& (!iqentry_mem[head2] || (iqentry_agen[head2] & iqentry_out[head2]) 
						|| (iqentry_a1_v[head2] && iqentry_a1[head7] != iqentry_a1[head2]))
					&& (!iqentry_mem[head3] || (iqentry_agen[head3] & iqentry_out[head3]) 
						|| (iqentry_a1_v[head3] && iqentry_a1[head7] != iqentry_a1[head3]))
					&& (!iqentry_mem[head4] || (iqentry_agen[head4] & iqentry_out[head4]) 
						|| (iqentry_a1_v[head4] && iqentry_a1[head7] != iqentry_a1[head4]))
					&& (!iqentry_mem[head5] || (iqentry_agen[head5] & iqentry_out[head5]) 
						|| (iqentry_a1_v[head5] && iqentry_a1[head7] != iqentry_a1[head5]))
					&& (!iqentry_mem[head6] || (iqentry_agen[head6] & iqentry_out[head6]) 
						|| (iqentry_a1_v[head6] && iqentry_a1[head7] != iqentry_a1[head6]))
					// ... and there isn't a barrier
    				&& !(iqentry_v[head0] && iqentry_mem[head0] && iqentry_memdb[head0]) 
                    && !(iqentry_v[head0] && iqentry_memsb[head0]) 
                    && !(iqentry_v[head1] && iqentry_mem[head1] && iqentry_memdb[head1]) 
                    && !(iqentry_v[head1] && iqentry_memsb[head1]) 
                    && !(iqentry_v[head2] && iqentry_mem[head2] && iqentry_memdb[head2]) 
                    && !(iqentry_v[head2] && iqentry_memsb[head2]) 
                    && !(iqentry_v[head3] && iqentry_mem[head3] && iqentry_memdb[head3]) 
                    && !(iqentry_v[head3] && iqentry_memsb[head3]) 
                    && !(iqentry_v[head4] && iqentry_mem[head4] && iqentry_memdb[head4]) 
                    && !(iqentry_v[head4] && iqentry_memsb[head4]) 
                    && !(iqentry_v[head5] && iqentry_mem[head5] && iqentry_memdb[head5]) 
                    && !(iqentry_v[head5] && iqentry_memsb[head5]) 
                    && !(iqentry_v[head6] && iqentry_mem[head6] && iqentry_memdb[head6]) 
                    && !(iqentry_v[head6] && iqentry_memsb[head6]) 
					// ... and, if it is a SW, there is no chance of it being undone
					&& (IsLoad(iqentry_instr[head7]) ||
                        (  !IsFlowCtrl(iqentry_instr[head0]) &&
                           !IsFlowCtrl(iqentry_instr[head1]) &&
                           !IsFlowCtrl(iqentry_instr[head2]) &&
                           !IsFlowCtrl(iqentry_instr[head3]) &&
                           !IsFlowCtrl(iqentry_instr[head4]) &&
                           !IsFlowCtrl(iqentry_instr[head5]) &&
                           !IsFlowCtrl(iqentry_instr[head6])));

	//
	// take requests that are ready and put them into DRAM slots

	if (dram0 == `DRAMSLOT_AVAIL)	dram0_exc <= `EXC_NONE;
	if (dram1 == `DRAMSLOT_AVAIL)	dram1_exc <= `EXC_NONE;
	if (dram2 == `DRAMSLOT_AVAIL)	dram2_exc <= `EXC_NONE;

    for (n = 0; n < QENTRIES; n = n + 1)
        if (iqentry_v[n] && iqentry_stomp[n]) begin
            iqentry_v[n] <= `INV;
            if (dram0_id[2:0] == n[2:0]) dram0 <= `DRAMSLOT_AVAIL;
            if (dram1_id[2:0] == n[2:0]) dram1 <= `DRAMSLOT_AVAIL;
            if (dram2_id[2:0] == n[2:0]) dram2 <= `DRAMSLOT_AVAIL;
        end

    for (n = 0; n < QENTRIES; n = n + 1)
        if (~iqentry_stomp[n] && iqentry_memissue[n] && iqentry_agen[n] && ~iqentry_out[n]) begin
            if (dram0 == `DRAMSLOT_AVAIL) begin
            dram0 		<= 2'd1;
            dram0_id 	<= { 1'b1, n[2:0] };
            dram0_instr <= iqentry_instr[n];
            dram0_tgt 	<= iqentry_tgt[n];
            dram0_data	<= iqentry_memndx[n] ? iqentry_a3[n] : iqentry_a2[n];
            dram0_addr	<= iqentry_a1[n];
            dram0_unc   <= iqentry_a1[n][31:20]==12'hFFD;
            dram0_memsize <= MemSize(iqentry_instr[n]);
            iqentry_out[n]	<= `VAL;
            end
            else if (dram1 == `DRAMSLOT_AVAIL) begin
            dram1 		<= 2'd1;
            dram1_id 	<= { 1'b1, n[2:0] };
            dram1_instr <= iqentry_instr[n];
            dram1_tgt 	<= iqentry_tgt[n];
            dram1_data	<= iqentry_memndx[n] ? iqentry_a3[n] : iqentry_a2[n];
            dram1_addr	<= iqentry_a1[n];
            dram1_unc   <= iqentry_a1[n][31:20]==12'hFFD;
            dram1_memsize <= MemSize(iqentry_instr[n]);
            iqentry_out[n]	<= `VAL;
            end
            else if (dram2 == `DRAMSLOT_AVAIL) begin
            dram2 		<= 2'd1;
            dram2_id 	<= { 1'b1, n[2:0] };
            dram2_instr	<= iqentry_instr[n];
            dram2_tgt 	<= iqentry_tgt[n];
            dram2_data	<= iqentry_memndx[n] ? iqentry_a3[n] : iqentry_a2[n];
            dram2_addr	<= iqentry_a1[n];
            dram2_unc   <= iqentry_a1[n][31:20]==12'hFFD;
            dram2_memsize <= MemSize(iqentry_instr[n]);
            iqentry_out[n]	<= `VAL;
            end
        end

    // This loop to finish off immediate prefix instructions. The prefix
    // instruction is done when the next instruction queues.
    // It's better to check a sequence number here because if the code is in a
    // loop that such that the previous iteration of the loop is still in the
    // queue the PC could match when we don;t really want a prefix for that
    // iteration.
    for (n = 0; n < QENTRIES; n = n + 1)
    begin
        if (IsImmp(iqentry_instr[n]) && iqentry_v[(n+1)&7]
            && (iqentry_sn[(n+1)&7]==iqentry_sn[n]+5'd1))
        iqentry_done[n] <= TRUE;
        if (!iqentry_v[n])
            iqentry_done[n] <= FALSE;
    end
      


    //
    // COMMIT PHASE (dequeue only ... not register-file update)
    //
    // look at head0 and head1 and let 'em write to the register file if they are ready
    //
//    always @(posedge clk) begin: commit_phase

    oddball_commit(commit0_v, head0);
    oddball_commit(commit1_v, head1);
    
	if (~|panic)
	case ({ iqentry_v[head0],
		iqentry_done[head0],
		iqentry_v[head1],
		iqentry_done[head1] })

	    // 4'b00_00	- neither valid; skip both
	    // 4'b00_01	- neither valid; skip both
	    // 4'b00_10	- skip head0, wait on head1
	    // 4'b00_11	- skip head0, commit head1
	    // 4'b01_00	- neither valid; skip both
	    // 4'b01_01	- neither valid; skip both
	    // 4'b01_10	- skip head0, wait on head1
	    // 4'b01_11	- skip head0, commit head1
	    // 4'b10_00	- wait on head0
	    // 4'b10_01	- wait on head0
	    // 4'b10_10	- wait on head0
	    // 4'b10_11	- wait on head0
	    // 4'b11_00	- commit head0, skip head1
	    // 4'b11_01	- commit head0, skip head1
	    // 4'b11_10	- commit head0, wait on head1
	    // 4'b11_11	- commit head0, commit head1

	    //
	    // retire 0
	    4'b10_00,
	    4'b10_01,
	    4'b10_10,
	    4'b10_11: ;

	    //
	    // retire 1
	    4'b00_10,
	    4'b01_10,
	    4'b11_10: begin
		if (iqentry_v[head0] || head0 != tail0) begin
		    iqentry_v[head0] <= `INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		    head0 <= head0 + 1;
		    head1 <= head1 + 1;
		    head2 <= head2 + 1;
		    head3 <= head3 + 1;
		    head4 <= head4 + 1;
		    head5 <= head5 + 1;
		    head6 <= head6 + 1;
		    head7 <= head7 + 1;
		    if (iqentry_v[head0] && iqentry_exc[head0])	panic <= `PANIC_HALTINSTRUCTION;
		    I <= I + 1;
		end
	    end

	    //
	    // retire 2
	    default: begin
		if ((iqentry_v[head0] && iqentry_v[head1] && iqentry_tgt2[head0]==6'd0) || (head0 != tail0 && head1 != tail0)) begin
		    iqentry_v[head0] <= `INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
	        iqentry_v[head1] <= `INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		    head0 <= head0 + 2;
		    head1 <= head1 + 2;
		    head2 <= head2 + 2;
		    head3 <= head3 + 2;
		    head4 <= head4 + 2;
		    head5 <= head5 + 2;
		    head6 <= head6 + 2;
		    head7 <= head7 + 2;
		    if (iqentry_v[head0] && iqentry_exc[head0])	panic <= `PANIC_HALTINSTRUCTION;
		    if (iqentry_v[head1] && iqentry_exc[head1])	panic <= `PANIC_HALTINSTRUCTION;
		    I <= I + 2;
		end
		else if (iqentry_v[head0] || head0 != tail0) begin
		    iqentry_v[head0] <= `INV;	// may conflict with STOMP, but since both are setting to 0, it is okay
		    head0 <= head0 + 1;
		    head1 <= head1 + 1;
		    head2 <= head2 + 1;
		    head3 <= head3 + 1;
		    head4 <= head4 + 1;
		    head5 <= head5 + 1;
		    head6 <= head6 + 1;
		    head7 <= head7 + 1;
		    if (iqentry_v[head0] && iqentry_exc[head0])	panic <= `PANIC_HALTINSTRUCTION;
		    I <= I + 1;
		end
	    end
	endcase


	rf_source[0] <= 0;
	L1_wr0 <= FALSE;
	L1_wr1 <= FALSE;
    icnxt <= FALSE;
    L2_nxt <= FALSE;
// Instruction cache state machine.
// On a miss first see if the instruction is in the L2 cache. No need to go to
// the BIU on an L1 miss.
// If not the machine will wait until the BIU loads the L2 cache.

    // Capture the previous ic state, used to determine how long to wait in
    // icstate #4.
    picstate <= icstate;
case(icstate)
IDLE:
    begin
        if (!ihit0) begin
            L1_adr <= {pcr[5:0],pc0[31:5],5'h0};
            L2_adr <= {pcr[5:0],pc0[31:5],5'h0};
            icwhich <= 1'b0;
            icstate <= IC2;
        end
        else if (!ihit1) begin
            L1_adr <= {pcr[5:0],pc1[31:5],5'h0};
            L2_adr <= {pcr[5:0],pc1[31:5],5'h0};
            icwhich <= 1'b1;
            icstate <= IC2;
        end
    end
IC2:    icstate <= IC3;
IC3:    icstate <= IC3a;
IC3a:    icstate <= IC4;
        // If data was in the L2 cache already there's no need to wait on the
        // BIU to retrieve data. It can be determined if the hit signal was
        // already active when this state was entered in which case waiting
        // will do no good.
        // The IC machine will stall in this state until the BIU has loaded the
        // L2 cache. 
IC4:    if (ihit2 && (bstate==B11||picstate==IC3a)) begin
            L1_wr1 <= TRUE;
            L1_wr0 <= TRUE;
            L1_adr <= L2_adr;
            L2_rdat <= L2_dato;
            icstate <= IC5;
        end
IC5:    icstate <= IC6;
IC6:    icstate <= IC7;
IC7:    begin
            icstate <= IDLE;
            icnxt <= TRUE;
        end
default:    icstate <= IDLE;
endcase

// Bus Interface Unit (BIU)
// Interfaces to the external bus which is WISHBONE compatible.
// Stores take precedence over other operations.
// Next data cache read misses are serviced.
// Uncached data reads are serviced.
// Finally L2 instruction cache misses are serviced.

case(bstate)
BIDLE:
    begin
        bwhich <= 2'b11;
        if (dram0==2'd1 && IsStore(dram0_instr)) begin
            dram0 <= 2'd2;
            bwhich <= 2'b00;
            we_o <= `HIGH;
            sel_o <= fnSelect(dram0_instr,dram0_addr);
            adr_o <= dram0_addr;
            dat_o <= fnDato(dram0_instr,dram1_data);
            cr_o <= IsSWC(dram0_instr);
    	    iqentry_done[ dram0_id[2:0] ] <= `VAL;
            iqentry_out[ dram0_id[2:0] ] <= `INV;
            bstate <= B13;
        end
        else if (dram1==2'd1 && IsStore(dram1_instr)) begin
            dram1 <= 2'd2;
            bwhich <= 2'b01;
            we_o <= `HIGH;
            sel_o <= fnSelect(dram1_instr,dram1_addr);
            adr_o <= dram1_addr;
            dat_o <= fnDato(dram1_instr,dram1_data);
            cr_o <= IsSWC(dram1_instr);
    	    iqentry_done[ dram1_id[2:0] ] <= `VAL;
            iqentry_out[ dram1_id[2:0] ] <= `INV;
            bstate <= B13;
        end
        else if (dram2==2'd1 && IsStore(dram2_instr)) begin
            dram2 <= 2'd2;
            bwhich <= 2'b10;
            we_o <= `HIGH;
            sel_o <= fnSelect(dram2_instr,dram2_addr);
            adr_o <= dram2_addr;
            dat_o <= fnDato(dram2_instr,dram2_data);
            cr_o <= IsSWC(dram2_instr);
    	    iqentry_done[ dram2_id[2:0] ] <= `VAL;
            iqentry_out[ dram2_id[2:0] ] <= `INV;
            bstate <= B13;
        end
        // Check for read misses on the data cache
        else if (!IsLWR(dram0_instr) && !dram0_unc && dram0==2'd1 && IsLoad(dram0_instr)) begin
            dram0 <= 2'd2;
            bwhich <= 2'b00;
            bstate <= B2; 
        end
        else if (!IsLWR(dram1_instr) && !dram1_unc && dram1==2'd1 && IsLoad(dram1_instr)) begin
            dram1 <= 2'd2;
            bwhich <= 2'b01;
            bstate <= B2; 
        end
        else if (!IsLWR(dram2_instr) && !dram2_unc && dram2==2'd1 && IsLoad(dram2_instr)) begin
            dram2 <= 2'd2;
            bwhich <= 2'b10;
            bstate <= B2; 
        end
        else if ((dram0_unc || IsLWR(dram0_instr)) && dram0==2'd1 && IsLoad(dram0_instr)) begin
            bwhich <= 2'b00;
            cyc_o <= `HIGH;
            stb_o <= `HIGH;
            sel_o <= fnSelect(dram0_instr,dram0_addr);
            adr_o <= {dram0_addr[31:3],3'b0};
            sr_o <=  IsLWR(dram0_instr);
            bstate <= B12;
        end
        else if ((dram1_unc || IsLWR(dram1_instr)) && dram1==2'd1 && IsLoad(dram1_instr)) begin
            bwhich <= 2'b01;
            cyc_o <= `HIGH;
            stb_o <= `HIGH;
            sel_o <= fnSelect(dram1_instr,dram1_addr);
            adr_o <= {dram1_addr[31:3],3'b0};
            sr_o <=  IsLWR(dram1_instr);
            bstate <= B12;
        end
        else if ((dram2_unc || IsLWR(dram2_instr)) && dram2==2'd1 && IsLoad(dram2_instr)) begin
            bwhich <= 2'b10;
            cyc_o <= `HIGH;
            stb_o <= `HIGH;
            sel_o <= fnSelect(dram2_instr,dram2_addr);
            adr_o <= {dram2_addr[31:3],3'b0};
            sr_o <=  IsLWR(dram2_instr);
            bstate <= B12;
        end
        // Check for L2 cache miss
        else if (!ihit2) begin
            cyc_o <= `HIGH;
            stb_o <= `HIGH;
            sel_o <= 8'hFF;
            icl_o <= `HIGH;
//            adr_o <= icwhich ? {pc0[31:5],5'b0} : {pc1[31:5],5'b0};
//            L2_adr <= icwhich ? {pc0[31:5],5'b0} : {pc1[31:5],5'b0};
            adr_o <= L1_adr;
            L2_adr <= L1_adr;
            bstate <= B7;
        end
    end
B1:
    if (ack_i) begin
        cyc_o <= `LOW;
        stb_o <= `LOW;
        we_o <= `LOW;
        sel_o <= 8'h00;
        cr_o <= 1'b0;
        // This isn't a good way of doing things; the state should be propagated
        // to the commit stage, however since this is a store we know there will
        // be no change of program flow. So the reservation status bit is set
        // here. The author wanted to avoid the complexity of propagating the
        // input signal to the commit stage. It does mean that the SWC
        // instruction should be surrounded by SYNC's.
        if (cr_o)
            sema[0] <= rbi_i; 
        case(bwhich)
        2'd0:   dram0 <= `DRAMREQ_READY;
        2'd1:   dram1 <= `DRAMREQ_READY;
        2'd2:   dram2 <= `DRAMREQ_READY;
        default:    ;
        endcase
        bstate <= BIDLE;
    end
B2: bstate <= B2a;
B2a: bstate <= B2b;
B2b: bstate <= B2c;
B2c:
    begin
    case(bwhich)
    2'd0:   if (dhit0) begin dram0 <= `DRAMREQ_READY; bstate <= BIDLE; end
            else begin
            cyc_o <= `HIGH;
            stb_o <= `HIGH;
            sel_o <= fnSelect(dram0_instr,dram0_addr);
            adr_o <= {dram0_addr[31:5],5'b0};
            bstate <= B2d;
            end
    2'd1:   if (dhit1) begin dram1 <= `DRAMREQ_READY; bstate <= BIDLE; end
            else begin
            cyc_o <= `HIGH;
            stb_o <= `HIGH;
            sel_o <= fnSelect(dram1_instr,dram1_addr);
            adr_o <= {dram1_addr[31:5],5'b0};
            bstate <= B2d;
            end
    2'd2:   if (dhit2) begin dram2 <= `DRAMREQ_READY; bstate <= BIDLE; end
            else begin
            cyc_o <= `HIGH;
            stb_o <= `HIGH;
            sel_o <= fnSelect(dram2_instr,dram2_addr);
            adr_o <= {dram2_addr[31:5],5'b0};
            bstate <= B2d;
            end
    default:    bstate <= BIDLE;
    endcase
    end
B2d:
    if (ack_i) begin
        adr_o <= adr_o + 32'd8;
        bstate <= B2d;
        if (adr_o[4:3]==2'd3) begin
            cyc_o <= `LOW;
            stb_o <= `LOW;
            sel_o <= 8'h00;
            bstate <= B4;
        end
    end
B3: begin
        stb_o <= `HIGH;
        bstate <= B2d;
    end
B4: bstate <= B5;
B5: bstate <= B6;
B6: begin
    case(bwhich)
    2'd0:   dram0 <= 2'd1;  // causes retest of dhit
    2'd1:   dram1 <= 2'd1;
    2'd2:   dram2 <= 2'd1;
    default:    ;
    endcase
    bstate <= BIDLE;
    end
B7:
    if (ack_i) begin
        //stb_o <= `LOW;
        bstate <= B7;
        if (L2_adr[4:3]==2'd3) begin
            cyc_o <= `LOW;
            stb_o <= `LOW;
            sel_o <= 8'h00;
            icl_o <= `LOW;
            bstate <= B9;
        end
        else begin
            //adr_o[4:3] <= adr_o[4:3] + 2'd1;
            L2_adr[4:3] <= L2_adr[4:3] + 2'd1;
        end
    end
B8: begin
        stb_o <= `HIGH;
        bstate <= B7;
    end
B9: bstate <= B10;
B10: bstate <= B11;
B11: begin
        bstate <= BIDLE;
        L2_nxt <= TRUE;
     end
B12:
    if (ack_i) begin
        cyc_o <= `LOW;
        stb_o <= `LOW;
        sr_o <= `LOW;
        xdati <= dat_i;
        case(bwhich)
        2'b00:  dram0 <= `DRAMREQ_READY;
        2'b01:  dram1 <= `DRAMREQ_READY;
        2'b10:  dram2 <= `DRAMREQ_READY;
        default:    ;
        endcase
        bstate <= BIDLE;
    end
// Three cycles to detemrine if there's a cache hit during a store.
B13:    bstate <= B14;
B14:    bstate <= B15;
B15:    begin
        cyc_o <= `HIGH;
        stb_o <= `HIGH;
        bstate <= B1;
        end
B16:    begin
            case(bwhich)
            2'd0:      if (dhit0) begin dram0 <= `DRAMREQ_READY; bstate <= B17; end
            2'd1:      if (dhit1) begin dram1 <= `DRAMREQ_READY; bstate <= B17; end
            2'd2:      if (dhit2) begin dram2 <= `DRAMREQ_READY; bstate <= B17; end
            default:   bstate <= BIDLE;
            endcase
            end
B17:    bstate <= B18;
B18:    bstate <= B19;
B19:    bstate <= BIDLE;
default:    bstate <= BIDLE;
endcase

//	#5 rf[0] = 0; rf_v[0] = 1; rf_source[0] = 0;

	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("%h #", pc0);

    $display ("Regfile:");
	for (n=0; n< 32; n=n+4) begin
	    $display("%d: %h %d %o   %d: %h %d %o   %d: %h %d %o   %d: %h %d %o#",
	       n, urf1.whichreg[n] ? urf1.regs1[n] : urf1.regs0[n], rf_v[n], rf_source[n],
	       n+1, urf1.whichreg[n+1] ? urf1.regs1[n+1] : urf1.regs0[n+1], rf_v[n+1], rf_source[n+1],
	       n+2, urf1.whichreg[n+2] ? urf1.regs1[n+2] : urf1.regs0[n+2], rf_v[n+2], rf_source[n+2],
	       n+3, urf1.whichreg[n+3] ? urf1.regs1[n+3] : urf1.regs0[n+3], rf_v[n+3], rf_source[n+3]
	       );
	end

	$display("%d %h #", take_branch, backpc);
	$display("%c%c A: %d %h %h #",
	    45, fetchbuf?45:62, fetchbufA_v, fetchbufA_instr, fetchbufA_pc);
	$display("%c%c B: %d %h %h #",
	    45, fetchbuf?45:62, fetchbufB_v, fetchbufB_instr, fetchbufB_pc);
	$display("%c%c C: %d %h %h #",
	    45, fetchbuf?62:45, fetchbufC_v, fetchbufC_instr, fetchbufC_pc);
	$display("%c%c D: %d %h %h #",
	    45, fetchbuf?62:45, fetchbufD_v, fetchbufD_instr, fetchbufD_pc);

	for (i=0; i<QENTRIES; i=i+1) 
	    $display("%c%c %d: %d %d %d %d %d %d %d %d %d %c%h 0%d(%d) %o %h %h %h %d %o %h %d %o %h %h#",
		(i[2:0]==head0)?"C":".", (i[2:0]==tail0)?"Q":".", i[2:0],
		iqentry_v[i], iqentry_done[i], iqentry_out[i], iqentry_bt[i], iqentry_memissue[i], iqentry_agen[i], iqentry_issue[i],
		((i==0) ? iqentry_islot[0] : (i==1) ? iqentry_islot[1] : (i==2) ? iqentry_islot[2] : (i==3) ? iqentry_islot[3] :
		 (i==4) ? iqentry_islot[4] : (i==5) ? iqentry_islot[5] : (i==6) ? iqentry_islot[6] : iqentry_islot[7]), iqentry_stomp[i],
		(IsFlowCtrl(iqentry_instr[i]) ? 98 : (IsMem(iqentry_instr[i])) ? 109 : 97), 
		iqentry_instr[i], iqentry_tgt[i], iqentry_utgt[i],
		iqentry_exc[i], iqentry_res[i], iqentry_a0[i], iqentry_a1[i], iqentry_a1_v[i],
		iqentry_a1_s[i], iqentry_a2[i], iqentry_a2_v[i], iqentry_a2_s[i], iqentry_pc[i],
		iqentry_sn[i]
		);
    $display("DRAM");
	$display("%d %h %h %c%d %o #",
	    dram0, dram0_addr, dram0_data, (IsFlowCtrl(dram0_instr) ? 98 : (IsMem(dram0_instr)) ? 109 : 97), 
	    dram0_instr, dram0_id);
	$display("%d %h %h %c%d %o #",
	    dram1, dram1_addr, dram1_data, (IsFlowCtrl(dram1_instr) ? 98 : (IsMem(dram1_instr)) ? 109 : 97), 
	    dram1_instr, dram1_id);
	$display("%d %h %h %c%d %o #",
	    dram2, dram2_addr, dram2_data, (IsFlowCtrl(dram2_instr) ? 98 : (IsMem(dram2_instr)) ? 109 : 97), 
	    dram2_instr, dram2_id);
	$display("%d %h %o %h #", dram_v, dram_bus, dram_id, dram_exc);
    $display("ALU");
	$display("%d %h %h %h %c%h %d %o %h #",
		alu0_dataready, alu0_argI, alu0_argA, alu0_argB, 
		 (IsFlowCtrl(alu0_instr) ? 98 : IsMem(alu0_instr) ? 109 : 97),
		alu0_instr, alu0_bt, alu0_sourceid, alu0_pc);
	$display("%d %h %o 0 #", alu0_v, alu0_bus, alu0_id);
	$display("%d %o %h #", alu0_branchmiss, alu0_sourceid, alu0_misspc); 

	$display("%d %h %h %h %c%h %d %o %h #",
		alu1_dataready, alu1_argI, alu1_argA, alu1_argB, 
		 (IsFlowCtrl(alu1_instr) ? 98 : IsMem(alu1_instr) ? 109 : 97),
		alu1_instr, alu1_bt, alu1_sourceid, alu1_pc);
	$display("%d %h %o 0 #", alu1_v, alu1_bus, alu1_id);
	$display("%d %o %h #", alu1_branchmiss, alu1_sourceid, alu1_misspc); 
    $display("Commit");
	$display("0: %d %h %o 0%d #", commit0_v, commit0_bus, commit0_id, commit0_tgt);
	$display("1: %d %h %o 0%d #", commit1_v, commit1_bus, commit1_id, commit1_tgt);
    $display("instructions committed: %d ticks: %d ", I, tick);
//
//	$display("\n\n\n\n\n\n\n\n");
//	$display("TIME %0d", $time);
//	$display("  pc0=%h", pc0);
//	$display("  pc1=%h", pc1);
//	$display("  reg0=%h, v=%d, src=%o", rf[0], rf_v[0], rf_source[0]);
//	$display("  reg1=%h, v=%d, src=%o", rf[1], rf_v[1], rf_source[1]);
//	$display("  reg2=%h, v=%d, src=%o", rf[2], rf_v[2], rf_source[2]);
//	$display("  reg3=%h, v=%d, src=%o", rf[3], rf_v[3], rf_source[3]);
//	$display("  reg4=%h, v=%d, src=%o", rf[4], rf_v[4], rf_source[4]);
//	$display("  reg5=%h, v=%d, src=%o", rf[5], rf_v[5], rf_source[5]);
//	$display("  reg6=%h, v=%d, src=%o", rf[6], rf_v[6], rf_source[6]);
//	$display("  reg7=%h, v=%d, src=%o", rf[7], rf_v[7], rf_source[7]);

//	$display("Fetch Buffers:");
//	$display("  %c%c fbA: v=%d instr=%h pc=%h     %c%c fbC: v=%d instr=%h pc=%h", 
//	    fetchbuf?32:45, fetchbuf?32:62, fetchbufA_v, fetchbufA_instr, fetchbufA_pc,
//	    fetchbuf?45:32, fetchbuf?62:32, fetchbufC_v, fetchbufC_instr, fetchbufC_pc);
//	$display("  %c%c fbB: v=%d instr=%h pc=%h     %c%c fbD: v=%d instr=%h pc=%h", 
//	    fetchbuf?32:45, fetchbuf?32:62, fetchbufB_v, fetchbufB_instr, fetchbufB_pc,
//	    fetchbuf?45:32, fetchbuf?62:32, fetchbufD_v, fetchbufD_instr, fetchbufD_pc);
//	$display("  branchback=%d backpc=%h", branchback, backpc);

//	$display("Instruction Queue:");
//	for (i=0; i<8; i=i+1) 
//	    $display(" %c%c%d: v=%d done=%d out=%d agen=%d res=%h op=%d bt=%d tgt=%d a1=%h (v=%d/s=%o) a2=%h (v=%d/s=%o) im=%h pc=%h exc=%h",
//		(i[2:0]==head0)?72:32, (i[2:0]==tail0)?84:32, i,
//		iqentry_v[i], iqentry_done[i], iqentry_out[i], iqentry_agen[i], iqentry_res[i], iqentry_op[i], 
//		iqentry_bt[i], iqentry_tgt[i], iqentry_a1[i], iqentry_a1_v[i], iqentry_a1_s[i], iqentry_a2[i], iqentry_a2_v[i], 
//		iqentry_a2_s[i], iqentry_a0[i], iqentry_pc[i], iqentry_exc[i]);

//	$display("Scheduling Status:");
//	$display("  iqentry0 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
//		iqentry_0_issue, iqentry_0_islot, iqentry_stomp[0], iqentry_source[0], iqentry_memready[0], iqentry_memissue[0]);
//	$display("  iqentry1 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
//		iqentry_1_issue, iqentry_1_islot, iqentry_stomp[1], iqentry_source[1], iqentry_memready[1], iqentry_memissue[1]);
//	$display("  iqentry2 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
//		iqentry_2_issue, iqentry_2_islot, iqentry_stomp[2], iqentry_source[2], iqentry_memready[2], iqentry_memissue[2]);
//	$display("  iqentry3 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
//		iqentry_3_issue, iqentry_3_islot, iqentry_stomp[3], iqentry_source[3], iqentry_memready[3], iqentry_memissue[3]);
//	$display("  iqentry4 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
//		iqentry_4_issue, iqentry_4_islot, iqentry_stomp[4], iqentry_source[4], iqentry_memready[4], iqentry_memissue[4]);
//	$display("  iqentry5 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b", 
//		iqentry_5_issue, iqentry_5_islot, iqentry_stomp[5], iqentry_source[5], iqentry_memready[5], iqentry_memissue[5]);
//	$display("  iqentry6 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
//		iqentry_6_issue, iqentry_6_islot, iqentry_stomp[6], iqentry_source[6], iqentry_memready[6], iqentry_memissue[6]);
//	$display("  iqentry7 issue=%d islot=%d stomp=%d source=%d - memready=%d memissue=%b",
//		iqentry_7_issue, iqentry_7_islot, iqentry_stomp[7], iqentry_source[7], iqentry_memready[7], iqentry_memissue[7]);

//	$display("ALU Inputs:");
//	$display("  0: avail=%d data=%d id=%o op=%d a1=%h a2=%h im=%h bt=%d",
//		alu0_available, alu0_dataready, alu0_sourceid, alu0_op, alu0_argA,
//		alu0_argB, alu0_argI, alu0_bt);
//	$display("  1: avail=%d data=%d id=%o op=%d a1=%h a2=%h im=%h bt=%d",
//		alu1_available, alu1_dataready, alu1_sourceid, alu1_op, alu1_argA,
//		alu1_argB, alu1_argI, alu1_bt);

//	$display("ALU Outputs:");
//	$display("  0: v=%d bus=%h id=%o bmiss=%d misspc=%h missid=%o",
//		alu0_v, alu0_bus, alu0_id, alu0_branchmiss, alu0_misspc, alu0_sourceid);
//	$display("  1: v=%d bus=%h id=%o bmiss=%d misspc=%h missid=%o",
//		alu1_v, alu1_bus, alu1_id, alu1_branchmiss, alu1_misspc, alu1_sourceid);

//	$display("DRAM Status:");
//	$display("  OUT: v=%d data=%h tgt=%d id=%o", dram_v, dram_bus, dram_tgt, dram_id);
//	$display("  dram0: status=%h addr=%h data=%h op=%d tgt=%d id=%o",
//	    dram0, dram0_addr, dram0_data, dram0_op, dram0_tgt, dram0_id);
//	$display("  dram1: status=%h addr=%h data=%h op=%d tgt=%d id=%o", 
//	    dram1, dram1_addr, dram1_data, dram1_op, dram1_tgt, dram1_id);
//	$display("  dram2: status=%h addr=%h data=%h op=%d tgt=%d id=%o",
//	    dram2, dram2_addr, dram2_data, dram2_op, dram2_tgt, dram2_id);

//	$display("Commit Buses:");
//	$display("  0: v=%d id=%o data=%h", commit0_v, commit0_id, commit0_bus);
//	$display("  1: v=%d id=%o data=%h", commit1_v, commit1_id, commit1_bus);

//
//	$display("Memory Contents:");
//	for (j=0; j<64; j=j+16)
//	    $display("  %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h", 
//		m[j+0], m[j+1], m[j+2], m[j+3], m[j+4], m[j+5], m[j+6], m[j+7],
//		m[j+8], m[j+9], m[j+10], m[j+11], m[j+12], m[j+13], m[j+14], m[j+15]);

	$display("");

	if (|panic) begin
	    $display("");
	    $display("-----------------------------------------------------------------");
	    $display("-----------------------------------------------------------------");
	    $display("---------------     PANIC:%s     -----------------", message[panic]);
	    $display("-----------------------------------------------------------------");
	    $display("-----------------------------------------------------------------");
	    $display("");
	    $display("instructions committed: %d", I);
	    $display("total execution cycles: %d", $time / 10);
	    $display("");
	end
	if (|panic && ~outstanding_stores) begin
	    $finish;
	end

    end // clock domain

// Branchmiss seems to be sticky sometimes during simulation. For instance branch miss
// and cache miss at same time. The branchmiss should clear before the core continues
// so the positive edge is detected to avoid incrementing the sequnce number too many
// times.
wire pebm;
edge_det uedbm (.rst(rst), .clk(clk), .ce(1'b1), .i(branchmiss), .pe(pebm), .ne(), .ee() );

always @(posedge clk)
if (rst)
    seq_num <= 5'd0;
else begin
    if (pebm)
        seq_num <= seq_num + 5'd3;
    else if (queued2)
        seq_num <= seq_num + 5'd2;
    else if (queued1)
        seq_num <= seq_num + 5'd1;
end

// Enqueue fetchbuf0 onto the tail of the instruction queue
task enque0;
input [2:0] tail;
begin
iqentry_sn   [tail]    <=  seq_num;
iqentry_v    [tail]    <=    `VAL;
iqentry_done [tail]    <=    `INV;
iqentry_out  [tail]    <=    `INV;
iqentry_res  [tail]    <=    `ZERO;
iqentry_res2 [tail]    <=    `ZERO;
iqentry_instr[tail]    <=    fetchbuf0_instr;             // BEQ
iqentry_bt   [tail]    <=    (IsBranch(fetchbuf0_instr) && predict_taken0);
iqentry_agen [tail]    <=    `INV;
// If the previous instruction was a hardware interrupt and this instruction is a hardware interrupt
// inherit the previous pc.
if (fetchbuf0_instr[`INSTRUCTION_OP]==`BRK && fetchbuf0_instr[15] &&
   (iqentry_instr[(tail-1)&7][`INSTRUCTION_OP]==`BRK && iqentry_instr[(tail-1)&7][15] && iqentry_v[(tail-1)&7]))
  iqentry_pc   [tail]    <= iqentry_pc[(tail-1)&7];
// If this instruction is a hardware interurpt and there's a previous immediate prefix
// -> inherit the address of the prefix
else if (fetchbuf0_instr[`INSTRUCTION_OP]==`BRK && fetchbuf0_instr[15])
  case(IQPrefixes(tail))
  2'd1:   iqentry_pc   [tail] <= iqentry_pc[(tail-1)&7];
  2'd2:   iqentry_pc   [tail] <= iqentry_pc[(tail-2)&7];
  default:   iqentry_pc   [tail] <= fetchbuf0_pc;
  endcase
else
   iqentry_pc   [tail] <= fetchbuf0_pc;
iqentry_alu  [tail]    <=   IsALU(fetchbuf0_instr);
iqentry_fc   [tail]    <=   IsFlowCtrl(fetchbuf0_instr);
iqentry_mem  [tail]    <=    fetchbuf0_mem;
iqentry_memndx[tail]   <=   IsMemNdx(fetchbuf0_instr);
iqentry_memdb[tail]    <=   IsMemdb(fetchbuf0_instr);
iqentry_memsb[tail]    <=   IsMemsb(fetchbuf0_instr);
iqentry_jmp  [tail]    <=    fetchbuf0_jmp;
iqentry_br   [tail]    <=  IsBranch(fetchbuf0_instr);
iqentry_fp   [tail]    <= FALSE;
iqentry_sync [tail]    <=  IsSync(fetchbuf0_instr);
iqentry_rfw  [tail]    <=    fetchbuf0_rfw;
//iqentry_ra   [tail0]    <=  fnRa(fetchbuf0_instr);
if (fetchbuf0_rfw) begin
    iqentry_tgt  [tail]    <= Rt0;
end
else begin
   iqentry_tgt  [tail]    <= 6'd0;
end
iqentry_tgt2 [tail]    <=   Rt0b;
iqentry_exc  [tail]    <=    `EXC_NONE;
iqentry_a0   [tail]    <=  assign_a0(tail, fetchbuf0_instr);
iqentry_a1   [tail]    <=    rfoa0;
iqentry_a1_v [tail]    <=    Source1Valid(fetchbuf0_instr) | rf_v[Ra0];
iqentry_a1_s [tail]    <=    rf_source[Ra0];
iqentry_a2   [tail]    <=    (fetchbuf0_instr[`INSTRUCTION_OP]==`CALL ||
                              fetchbuf0_instr[`INSTRUCTION_OP]==`JAL) ? fetchbuf0_pc + 32'd4 :
                              rfob0;
iqentry_a2_v [tail]    <=    Source2Valid(fetchbuf0_instr) | rf_v[Rb0];
iqentry_a2_s [tail]    <=    rf_source[Rb0];
iqentry_a3   [tail]    <=    rfoc0;
iqentry_a3_v [tail]    <=    Source3Valid(fetchbuf0_instr) | rf_v[Rc0];
iqentry_a3_s [tail]    <=    rf_source[Rc0];
end
endtask

task FetchAB;
begin
    if (insn0[`INSTRUCTION_OP]==`EXEC)
        fetchbufA_instr <= codebuf[insn0[21:16]];
    else
        fetchbufA_instr <= insn0;
    fetchbufA_v <= `VAL;
    fetchbufA_pc <= pc0;
    if (insn1[`INSTRUCTION_OP]==`EXEC)
        fetchbufB_instr <= codebuf[insn1[21:16]];
    else
        fetchbufB_instr <= insn1;
    fetchbufB_v <= `VAL;
    fetchbufB_pc <= pc1;
    if (phit) begin
    pc0 <= pc0 + 8;
    pc1 <= pc1 + 8;
    end
end
endtask

task FetchCD;
begin
    if (insn0[`INSTRUCTION_OP]==`EXEC)
        fetchbufC_instr <= codebuf[insn0[21:16]];
    else
        fetchbufC_instr <= insn0;
    fetchbufC_v <= `VAL;
    fetchbufC_pc <= pc0;
    if (insn1[`INSTRUCTION_OP]==`EXEC)
        fetchbufD_instr <= codebuf[insn1[21:16]];
    else
        fetchbufD_instr <= insn1;
    fetchbufD_v <= `VAL;
    fetchbufD_pc <= pc1;
    if (phit) begin
    pc0 <= pc0 + 8;
    pc1 <= pc1 + 8;
    end
end
endtask

// This task takes care of commits for things other than the register file.
task oddball_commit;
input v;
input [2:0] head;
begin
    if (v) begin
        case(iqentry_instr[head][`INSTRUCTION_OP])
        `BRK:   begin
                    epc <= iqentry_res[head];
                    epc0 <= epc;
                    epc1 <= epc0;
                    epc2 <= epc1;
                    epc3 <= epc2;
                    epc4 <= epc3;
                    epc5 <= epc4;
                    epc6 <= epc5;
                    epc7 <= epc6;
                    epc8 <= epc7;
                    mstatus <= {mstatus[127:112],mstatus[97:0],cpl,ol,im};
                    cause[3'd0] <= {7'd0,iqentry_instr[head][14:6]};
                    // For hardware interrupts only, set a new mask level
                    if (!(iqentry_instr[head][15]))
                        im <= iqentry_instr[head][18:16];
                    ol <= 3'd0;
                    cpl <= 8'h00;
                    sema[0] <= 1'b0;
                end
        `RR:
            case(iqentry_instr[head][`INSTRUCTION_S2])
            `SEI:   im <= iqentry_res[head][2:0];   // S1
            `RTI:   begin
                    im <= mstatus[2:0];
                    ol <= mstatus[5:3];
                    cpl <= mstatus[13:6];
                    mstatus <= {mstatus[127:112],8'h00,3'd0,3'd7,mstatus[111:14]};
                    epc <= epc0;
                    epc0 <= epc1;
                    epc1 <= epc2;
                    epc2 <= epc3;
                    epc3 <= epc4;
                    epc4 <= epc5;
                    epc5 <= epc6;
                    epc6 <= epc7;
                    epc7 <= epc8;
                    epc8 <= BRKPC;
                    sema[0] <= 1'b0;
                    sema[iqentry_instr[head][21:16]] <= 1'b0;
                    end
            default: ;
            endcase
        `CSRRW: write_csr(iqentry_instr[head][31:16],iqentry_a1[head]);
        `REX:
            // Can only redirect to a lower level
            if (ol < iqentry_instr[head][13:11]) begin
                ol <= iqentry_instr[head][13:11];
                badaddr[iqentry_instr[head][13:11]] <= badaddr[ol];
                cause[iqentry_instr[head][13:11]] <= cause[ol];
                cpl <= iqentry_instr[head][23:16] | iqentry_a1[head][7:0];
            end
        default:    ;
        endcase
    end
end
endtask

task read_csr;
input [13:0] csrno;
output [63:0] dat;
begin
    casex(csrno[10:0])
    `CSR_HARTID:    dat <= hartid;
    `CSR_TICK:      dat <= tick;
    `CSR_PCR:       dat <= pcr;
    `CSR_PCR2:      dat <= pcr2;
    `CSR_SEMA:      dat <= sema;
    `CSR_TVEC:      dat <= tvec[csrno[2:0]];
    `CSR_CAUSE:     dat <= {48'd0,cause[csrno[13:11]]};
    `CSR_EPC:       dat <= epc;
    `CSR_STATUSL:   dat <= mstatus[63:0];
    `CSR_STATUSH:   dat <= mstatus[127:64];
    `CSR_CODEBUF:   dat <= codebuf[csrno[5:0]];
    `CSR_INFO:
                    case(csrno[3:0])
                    4'd0:   dat <= "Finitron";  // manufacturer
                    4'd1:   dat <= "        ";
                    4'd2:   dat <= "64 bit  ";  // CPU class
                    4'd3:   dat <= "        ";
                    4'd4:   dat <= "FT64    ";  // Name
                    4'd5:   dat <= "        ";
                    4'd6:   dat <= 64'd1;       // model #
                    4'd7:   dat <= 64'd1;       // serial number
                    4'd8:   dat <= {32'd16384,32'd16384};   // cache sizes instruction,data
                    4'd9:   dat <= 64'd0;
                    default:    dat <= 64'd0;
                    endcase
    default:        dat <= 64'hCCCCCCCCCCCCCCCC;
    endcase
end
endtask

task write_csr;
input [15:0] csrno;
input [63:0] dat;
begin
    case(csrno[15:14])
    2'd1:   // CSRRW
        casex(csrno[10:0])
        `CSR_PCR:       pcr <= dat[31:0];
        `CSR_PCR2:      pcr2 <= dat;
        `CSR_SEMA:      sema <= dat;
        `CSR_CAUSE:     cause[csrno[13:11]] <= dat[15:0];
        `CSR_TVEC:      tvec[csrno[2:0]] <= dat[31:0];
        `CSR_EPC:       epc <= dat;
        `CSR_STATUSL:   mstatus[63:0] <= dat;
        `CSR_STATUSH:   mstatus[127:64] <= dat;
        `CSR_CODEBUF:   codebuf[csrno[5:0]] <= dat;
        default:    ;
        endcase
    2'd2:   // CSRRS
        case(csrno[11:0])
        `CSR_PCR:       pcr[31:0] <= pcr[31:0] | dat[31:0];
        `CSR_PCR2:      pcr2 <= pcr2 | dat;
        `CSR_SEMA:      sema <= sema | dat;
        `CSR_STATUSL:    mstatus[63:0] <= mstatus[63:0] | dat;
        default:    ;
        endcase
    2'd3:   // CSRRC
        case(csrno[11:0])
        `CSR_PCR:       pcr <= pcr & ~dat;
        `CSR_PCR2:      pcr2 <= pcr2 & ~dat;
        `CSR_SEMA:      sema <= sema & ~dat;
        `CSR_STATUSL:    mstatus[63:0] <= mstatus[63:0] & ~dat;
        default:    ;
        endcase
    default:    ;
    endcase
end
endtask

// set_exception:
// Used to requeue the instruction as an exception if an exception occurs.

task set_exception;
input [2:0] id;     // instruction queue id
input [8:0] exc;    // exception number
begin
    iqentry_instr [id[2:0] ] <= {16'd0,1'b1,exc,`BRK};
    iqentry_mem[id[2:0]] <= `FALSE;
    iqentry_rfw[id[2:0]] <= `FALSE;
    iqentry_a1_v [id[2:0]] <= `TRUE;        // Flag arguments as valid
    iqentry_a2_v [id[2:0]] <= `TRUE;
    iqentry_a3_v [id[2:0]] <= `TRUE;
    iqentry_out [id[2:0]] <= `FALSE;
    iqentry_agen [id[2:0]] <= `FALSE;
    iqentry_tgt[id[2:0]] <= 6'd0;
    iqentry_tgt2[id[2:0]] <= 6'd0;
    //exception_set = `TRUE;
end
endtask

function [63:0] assign_a0;
input [2:0] tail;
input [31:0] fb_instr;
begin
    if (IsShifti(fb_instr)||IsSEI(fb_instr))
        assign_a0 = {58'd0,fb_instr[21],fb_instr[`INSTRUCTION_RB]};
	else if (iqentry_instr[(tail-1) & 7][`INSTRUCTION_OP]==`IMML && fb_instr[`INSTRUCTION_OP]==`IMMM)
        assign_a0 = {fb_instr[27:6],iqentry_a0[(tail-1)&7][41:0]};
    else if (iqentry_instr[(tail-1) & 7][`INSTRUCTION_OP]==`IMML || iqentry_instr[(tail-1) & 7][`INSTRUCTION_OP]==`IMMM)
        assign_a0 = {iqentry_a0[(tail-1)&7][63:16],fb_instr[31:16]};
    else if (fb_instr[`INSTRUCTION_OP] == `IMML)
        assign_a0 = {{22{fb_instr[`INSTRUCTION_SB]}},fb_instr[31:6],16'h0000}; 
    else if (fb_instr[`INSTRUCTION_OP] == `IMMM)
        assign_a0 = {fb_instr[27:6],42'h00000000};
    else if (fb_instr[`INSTRUCTION_OP] == `CALL)
        assign_a0 = {{36{fb_instr[31]}},fb_instr[31:6],2'd0};
    else 
        assign_a0 = {{48{fb_instr[`INSTRUCTION_SB]}},fb_instr[31:16]};
end
endfunction

function [1:0] IQPrefixes;
input [2:0] tail;
IQPrefixes = IsImmp(iqentry_instr[(tail-1)&7]) & IsImmp(iqentry_instr[(tail-2)&7]) ? 2'd2 :
                 IsImmp(iqentry_instr[(tail-1)&7]) ? 2'd1 : 2'd0;
endfunction

endmodule


module decoder5 (num, out);
input [4:0] num;
output [31:1] out;
reg [31:1] out;

always @(num)
case (num)
    5'd0 :	out <= 31'b0000000000000000000000000000000;
    5'd1 :	out <= 31'b0000000000000000000000000000001;
    5'd2 :	out <= 31'b0000000000000000000000000000010;
    5'd3 :	out <= 31'b0000000000000000000000000000100;
    5'd4 :	out <= 31'b0000000000000000000000000001000;
    5'd5 :	out <= 31'b0000000000000000000000000010000;
    5'd6 :	out <= 31'b0000000000000000000000000100000;
    5'd7 :	out <= 31'b0000000000000000000000001000000;
    5'd8 :	out <= 31'b0000000000000000000000010000000;
    5'd9 :	out <= 31'b0000000000000000000000100000000;
    5'd10:	out <= 31'b0000000000000000000001000000000;
    5'd11:	out <= 31'b0000000000000000000010000000000;
    5'd12:	out <= 31'b0000000000000000000100000000000;
    5'd13:	out <= 31'b0000000000000000001000000000000;
    5'd14:	out <= 31'b0000000000000000010000000000000;
    5'd15:	out <= 31'b0000000000000000100000000000000;
    5'd16:	out <= 31'b0000000000000001000000000000000;
    5'd17:	out <= 31'b0000000000000010000000000000000;
    5'd18:	out <= 31'b0000000000000100000000000000000;
    5'd19:	out <= 31'b0000000000001000000000000000000;
    5'd20:	out <= 31'b0000000000010000000000000000000;
    5'd21:	out <= 31'b0000000000100000000000000000000;
    5'd22:	out <= 31'b0000000001000000000000000000000;
    5'd23:	out <= 31'b0000000010000000000000000000000;
    5'd24:	out <= 31'b0000000100000000000000000000000;
    5'd25:	out <= 31'b0000001000000000000000000000000;
    5'd26:	out <= 31'b0000010000000000000000000000000;
    5'd27:	out <= 31'b0000100000000000000000000000000;
    5'd28:	out <= 31'b0001000000000000000000000000000;
    5'd29:	out <= 31'b0010000000000000000000000000000;
    5'd30:	out <= 31'b0100000000000000000000000000000;
    5'd31:	out <= 31'b1000000000000000000000000000000;
endcase

endmodule

module decoder6 (num, out);
input [5:0] num;
output [63:1] out;

wire [63:0] out1;

assign out1 = 64'd1 << num;
assign out = out1[63:1];

endmodule

