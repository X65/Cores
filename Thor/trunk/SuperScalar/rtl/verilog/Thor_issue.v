// ============================================================================
//        __
//   \\__/ o\    (C) 2013  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// Thor SuperScalar
// Instruction fetch logic
//
// ============================================================================
//
    //
    // ISSUE 
    //
    // determines what instructions are ready to go, then places them
    // in the various ALU queues.  
    // also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
    //

	alu0_dataready <= alu0_available 
				&& ((iqentry_issue[0] && iqentry_0_islot == 2'd0 && !iqentry_stomp[0])
				 || (iqentry_issue[1] && iqentry_1_islot == 2'd0 && !iqentry_stomp[1])
				 || (iqentry_issue[2] && iqentry_2_islot == 2'd0 && !iqentry_stomp[2])
				 || (iqentry_issue[3] && iqentry_3_islot == 2'd0 && !iqentry_stomp[3])
				 || (iqentry_issue[4] && iqentry_4_islot == 2'd0 && !iqentry_stomp[4])
				 || (iqentry_issue[5] && iqentry_5_islot == 2'd0 && !iqentry_stomp[5])
				 || (iqentry_issue[6] && iqentry_6_islot == 2'd0 && !iqentry_stomp[6])
				 || (iqentry_issue[7] && iqentry_7_islot == 2'd0 && !iqentry_stomp[7]));

	alu1_dataready <= alu1_available 
				&& ((iqentry_issue[0] && iqentry_0_islot == 2'd1 && !iqentry_stomp[0])
				 || (iqentry_issue[1] && iqentry_1_islot == 2'd1 && !iqentry_stomp[1])
				 || (iqentry_issue[2] && iqentry_2_islot == 2'd1 && !iqentry_stomp[2])
				 || (iqentry_issue[3] && iqentry_3_islot == 2'd1 && !iqentry_stomp[3])
				 || (iqentry_issue[4] && iqentry_4_islot == 2'd1 && !iqentry_stomp[4])
				 || (iqentry_issue[5] && iqentry_5_islot == 2'd1 && !iqentry_stomp[5])
				 || (iqentry_issue[6] && iqentry_6_islot == 2'd1 && !iqentry_stomp[6])
				 || (iqentry_issue[7] && iqentry_7_islot == 2'd1 && !iqentry_stomp[7]));

	for (n = 0; n < 8; n = n + 1)
	begin
		if (iqentry_v[n] && iqentry_stomp[n]) begin
			iqentry_v[n] <= `INV;
			if (dram0_id[2:0] == n[2:0])	dram0 <= `DRAMSLOT_AVAIL;
			if (dram1_id[2:0] == n[2:0])	dram1 <= `DRAMSLOT_AVAIL;
			if (dram2_id[2:0] == n[2:0])	dram2 <= `DRAMSLOT_AVAIL;
		end
		else if (iqentry_issue[n]) begin
			case (iqentry_0_islot) 
			2'd0: if (alu0_available) begin
				alu0_sourceid	<= n[3:0];
				alu0_op		<= fnIsMem(iqentry_op[n]) ? `ADDI : iqentry_op[n];
				alu0_bt		<= iqentry_bt[n];
				alu0_pc		<= iqentry_pc[n];
				alu0_argA	<= iqentry_a1_v[n] ? iqentry_a1[0]
							: (iqentry_a1_s[n] == alu0_id) ? alu0_bus
							: (iqentry_a1_s[n] == alu1_id) ? alu1_bus
							: 64'hDEADDEADDEADDEAD;
				alu0_argB	<= iqentry_imm[n]
							? iqentry_a0[n]
							: (iqentry_a2_v[n] ? iqentry_a2[0]
							: (iqentry_a2_s[n] == alu0_id) ? alu0_bus
							: (iqentry_a2_s[n] == alu1_id) ? alu1_bus
							: 64'hDEADDEADDEADDEAD;
				alu0_argI	<= iqentry_a0[n];
				end
			2'd1: if (alu1_available) begin
				alu1_sourceid	<= n[3:0];
				alu1_op		<= fnIsMem(iqentry_op[n]) ? `ADDI : iqentry_op[n];
				alu1_bt		<= iqentry_bt[n];
				alu1_pc		<= iqentry_pc[n];
				alu1_argA	<= iqentry_a1_v[n] ? iqentry_a1[0]
							: (iqentry_a1_s[n] == alu0_id) ? alu0_bus
							: (iqentry_a1_s[n] == alu1_id) ? alu1_bus
							: 64'hDEADDEADDEADDEAD;
				alu1_argB	<= iqentry_imm[n]
							? iqentry_a0[n]
							: (iqentry_a2_v[n] ? iqentry_a2[n]
							: (iqentry_a2_s[n] == alu0_id) ? alu0_bus
							: (iqentry_a2_s[n] == alu1_id) ? alu1_bus
							: 64'hDEADDEADDEADDEAD;
				alu1_argI	<= iqentry_a0[n];
				end
			default: panic <= `PANIC_INVALIDISLOT;
			endcase
			iqentry_out[n] <= `TRUE;
			// if it is a memory operation, this is the address-generation step ... collect result into arg1
			if (iqentry_mem[n]) begin
				iqentry_a1_v[n] <= `FALSE;
				iqentry_a1_s[n] <= n[3:0];
			end
		end
	end

