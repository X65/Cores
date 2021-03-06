#include "stdafx.h"
#include <stdio.h>

void clsCPU::Reset()
	{
		km = true;
		brk = 0;
		im = true;
		irq = false;
		nmi = false;
		StatusHWI = false;
		isRunning = false;
		regs[0] = 0;
		pc = 0x10000;
		vbr = 0;
		tick = 0;
		rvecno = 0;
	};
	void clsCPU::BuildConstant() {
		if (immcnt==2) {
			imm1 = (((wir >> 6) << 16) | (ir >> 16));
			imm2 = ((wir >> 6) >> 16);
			imm2 = imm2 | ((xir >> 6) << 10);
		}
		else if (immcnt==1) {
			imm1 = (((xir >> 6) << 16) | (ir >> 16));
			imm2 = ((xir >> 6) >> 16);
			imm2 = imm2 | ((xir&0x80000000) ? 0xFFFFFC00 : 0x00000000);
		}
		else {
			sir = ir;
			imm1 = (sir >> 16);
			imm2 = (sir&0x80000000) ? 0xFFFFFFFF : 0x00000000;
		}
		imm = ((__int64)imm2 << 32) | imm1;
	};
	void clsCPU::Step()
	{
		unsigned int ad, opc;
		unsigned int irx, iry;
		int nn;
		int sc;
		int ir21;
		__int64 imm4,imm9,imm9bra;
		if (imcd > 0) {
			imcd--;
			if (imcd==1)
				im = 0;
		}
		tick = tick + 1;
		//---------------------------------------------------------------------------
		// Instruction Fetch stage
		//---------------------------------------------------------------------------
		wir = xir;
		xir = ir;
		if (nmi && !StatusHWI)
			sir = ir = 0x38 + (0x1E << 7) + (510 << 17) + 0x80000000L;
		else if (irq && ~im && !StatusHWI)
			sir = ir = 0x38 + (0x1E << 7) + (vecno << 17) + 0x80000000L;
		else {
			// Read the pc in two characters as the address may be character aligned.
			irx = system1->Read(pc);
			irx = (irx >> ((pc & 3)<<3)) & 0xFFFF;
			iry = system1->Read(pc+2);
			iry = (iry >> (((pc+2) & 3)<<3)) & 0xFFFF;
			sir = ir = (iry << 16) | irx;
//			sir = ir = system1->Read(pc);
		}
		ir21 = (ir >> 21) & 0x1F;
		if (ir21 & 0x10)
			ir21 |= 0xFFFFFFE0L;
		for (nn = 39; nn >= 0; nn--)
			pcs[nn] = pcs[nn-1];
		pcs[0] = pc;
		imm4 = (ir >> 12) & 15;
		imm9 = ((ir >> 7) & 0x1ff) << 3;	// For RTS2
		if (imm4 & 0x8)
			imm4 |= 0xFFFFFFFFFFFFFFF0LL;
		imm9bra = ((ir >> 7) & 0x1ff) ;	// For BRAS
		if (imm9bra & 0x100)
			imm9bra |= 0xFFFFFFFFFFFFFF00LL;
dc:
		//---------------------------------------------------------------------------
		// Decode stage
		//---------------------------------------------------------------------------
		opcode = ir & 0x7F;
		func = ir >> 25;
		Ra = (ir >> 6) & 0x1f;
		Rb = (ir >> 11) & 0x1F;
		Rc = (ir >> 16) & 0x1f;
		if ((ir>>26)==2) {
			Rt = (ir >> 16) & 0x1F;
		}
		else
			Rt = (ir >> 11) & 0x1F;
		Bn = ((ir >> 11) & 0x1f) | (((ir >> 21) & 1) << 5);
		sc = (ir >> 21) & 3;
		mb = imm & 0x3f;
		me = (imm >> 8) & 0x3f;

		a = opera.ai = regs[Ra];
		b = operb.ai = regs[Rb];
		c = operc.ai = regs[Rc];
		ua = a;
		ub = b;
		res = 0;
		opcode = ir & 0x3f;
		opc = pc;
		pc = pc + 4;

		//---------------------------------------------------------------------------
		// Execute stage
		//---------------------------------------------------------------------------
		switch(opcode) {
		case IRR:
			switch(ir >> 26) {
			case ISEI:  im = a|imm; break;
			case IRTI:
				km = ipc & 1;
				pc = ipc & -2;
				regs[30] = isp;
				StatusHWI = false;
				imcd = 4;
				break;
			case IWAIT:	if (irq || nmi) break;
			case IADD:
				res = a + b;
				break;
			case ISUB:
				res = a - b;
				break;
			case ICMP:
				if (a < b)
					res = -1LL;
				else if (a == b)
					res=0LL;
				else
					res=1LL;
				break;
			case ICMPU:
				if (ua < ub)
					res = -1LL;
				else if (ua == ub)
					res=0LL;
				else
					res=1LL;
				break;
			case IMUL:
				res = a * b;
				break;
			case IMULSU:
				res = a * ub;
				break;
			case IMULU:
				res = ua * ub;
				break;
			case IDIVMOD:
				res = a / b;
				res2 = a % b;
				break;
			case IDIVMODU:
				res = ua / ub;
				res2 = ua % ub;
				break;
			case IDIVMODSU:
				res = a / ub;
				res2 = a % ub;
				break;
			case IAND:
				res = a & b;
				break;
			case IOR:
				res = a | b;
				break;
			case IXOR:
				res = a ^ b;
				break;
			case INAND:
				res = ~(a & b);
				break;
			case INOR:
				res = ~(a | b);
				break;
			case IXNOR:
				res = ~(a ^ b);
				break;
			case ILBX:
				ad = a + (b << sc);
				res = (system1->Read(ad) >> ((ad & 3)<<3)) & 0xFF;
				if (res & 0x80) res |= 0xFFFFFFFFFFFFFF00LL;
				break;
			case ILBUX:
				ad = a + (b << sc);
				res = (system1->Read(ad) >> ((ad & 3)<<3)) & 0xFF;
				break;
			case ILCX:
				ad = a + (b << sc);
				res = (system1->Read(ad) >> ((ad & 3)<<3)) & 0xFFFF;
				if (res & 0x8000) res |= 0xFFFFFFFFFFFF0000LL;
				break;
			case ILCUX:
				ad = a + (b << sc);
				res = (system1->Read(ad) >> ((ad & 3)<<3)) & 0xFFFF;
				break;
			case ILHX:
				ad = a + (b << sc);
				res = (system1->Read(ad) >> ((ad & 3)<<3));
				if (res & 0x80000000LL) res |= 0xFFFFFFFF00000000LL;
				break;
			case ILHUX:
				ad = a + (b << sc);
				res = (system1->Read(ad) >> ((ad & 3)<<3));
				res &= 0x00000000FFFFFFFFLL;
				break;
			case ILWX:
				ad = a + (b << sc);
				res = system1->Read(ad);
				res |= ((unsigned __int64)system1->Read(ad+4)) << 32;
				break;
			case ISBX:
				Rt = 0;
				ad = a + (b << sc);
				switch(ad & 7) {
				case 0:
					system1->Write(ad,(int)regs[Rc],0x1);
					break;
				case 1:
					system1->Write(ad,(int)regs[Rc],0x2);
					break;
				case 2:
					system1->Write(ad,(int)regs[Rc],0x4);
					break;
				case 3:
					system1->Write(ad,(int)regs[Rc],0x8);
					break;
				case 4:
					system1->Write(ad,(int)regs[Rc],0x1);
					break;
				case 5:
					system1->Write(ad,(int)regs[Rc],0x2);
					break;
				case 6:
					system1->Write(ad,(int)regs[Rc],0x4);
					break;
				case 7:
					system1->Write(ad,(int)regs[Rc],0x8);
					break;
				}
				break;
			case ISCX:
				Rt = 0;
				ad = a + (b << sc);
				switch(ad & 7) {
				case 0:
					system1->Write(ad,(int)regs[Rc],0x3);
					break;
				case 1:
					system1->Write(ad,(int)regs[Rc],0x6);
					break;
				case 2:
					system1->Write(ad,(int)regs[Rc],0xC);
					break;
				case 3:
					system1->Write(ad,(int)regs[Rc],0x8);
					break;
				case 4:
					system1->Write(ad,(int)regs[Rc],0x3);
					break;
				case 5:
					system1->Write(ad,(int)regs[Rc],0x6);
					break;
				case 6:
					system1->Write(ad,(int)regs[Rc],0xC);
					break;
				case 7:
					system1->Write(ad,(int)regs[Rc],0x8);
					break;
				}
				break;
			case ISHX:
				Rt = 0;
				ad = a + (b << sc);
				system1->Write(ad,(int)regs[Rc],0xF);
				break;
			case ISWX:
				Rt = 0;
				ad = a + (b << sc);
				system1->Write(ad,(int)regs[Rc],0xF);
				system1->Write(ad+4,(int)(regs[Rc]>>32),0xF);
				break;
			case IPUSH:
				ad = (unsigned int)regs[Ra]+ir21;
				Rt2 = (ir >> 16) & 0x1F;
				Rt = 0;
				regs[Rt2] += ir21;
				system1->Write(ad,(int)regs[Rb],0xF);
				system1->Write(ad+4,(int)(regs[Rb]>>32),0xF);
				break;
			case IPOP:
				ad = (unsigned int)regs[Ra];
				Rt2 = (ir >> 16) & 0x1F;
				Rt = (ir >> 11) & 0x1F;
				regs[Rt2] += ir21;
				res = system1->Read(ad,0);
				res |= ((unsigned __int64)system1->Read(ad+4,0)) << 32;
				break;
			case ISHIFT:
				switch((ir >> 22) & 0xF) {
				case ISHL:
					res = ua << (b & 0x3f);
					break;
				case ISHR:
					res = ua >> (b & 0x3f);
					break;
				case IASL:
					res = a << (b & 0x3f);
					break;
				case IASR:
					res = a >> (b & 0x3f);
					break;
				case IROL:
					res = (a << (b & 0x3f)) | (a >> ((64-b)&0x3f));
					break;
				case IROR:
					res = (a >> (b & 0x3f)) | (a << ((64-b)&0x3f));
					break;
				case ISHLI:
					res = ua << (Bn & 0x3f);
					break;
				case ISHRI:
					res = ua >> (Bn & 0x3f);
					break;
				case IASLI:
					res = a << (Bn & 0x3f);
					break;
				case IASRI:
					res = a >> (Bn & 0x3f);
					break;
				case IROLI:
					res = (ua << (Bn & 0x3f)) | (ua >> ((64-Bn)&0x3f));
					break;
				case IRORI:
					res = (ua >> (Bn & 0x3f)) | (ua << ((64-Bn)&0x3f));
					break;
				default: ;
				}
				break;
			case IBTFLD:
				bmask = 0;
				for (nn = 0; nn < me-mb+1; nn ++) {
					bmask = (bmask << 1) | 1;
				}
				switch((ir >> 29) & 7) {
				case IBFSET:
					bmask <<= mb;
					res = a | bmask << mb;
					break;
				case IBFCLR:
					bmask <<= mb;
					res = a & ~(bmask << mb);
					break;
				case IBFCHG:
					bmask <<= mb;
					res = a ^ (bmask << mb);
					break;
				case IBFINS:
					bmask <<= mb;
					c &= ~(bmask << mb);
					res = c | ((a & bmask) << mb);
					break;
				case IBFINSI:
					bmask <<= mb;
					c &= ~(bmask << mb);
					res = c | ((Ra & bmask) << mb);
					break;
				case IBFEXT:
					res = (a >> mb) & bmask;
					if ((res & ((bmask + 1) >> 1)) != 0) res |= ~bmask;
					break;
				case IBFEXTU:
					res = (a >> mb) & bmask;
					break;
				}
				break;
			}
			break;
		case ICHK:
			Rt = 0;
			r1 = a >= b;
			r2 = a < c;
			res = r1 && r2;
			if (!res) {
				ir = 0x03cc0f38;
				goto dc;
			}
			break;
		case IADD:
			BuildConstant();
			res = a + imm;
			break;
		case ISUB:
			BuildConstant();
			res = a - imm;
			break;
		case ICMP:
			BuildConstant();
			if (a < imm)
				res = -1LL;
			else if (a==imm)
				res = 0LL;
			else
				res = 1LL;
			break;
		case ICMPU:
			BuildConstant();
			if (ua < (unsigned __int64)imm)
				res = 0xFFFFFFFFFFFFFFFFLL;
			else if (a==imm)
				res = 0LL;
			else
				res = 1LL;
			break;
		case IMUL:
			BuildConstant();
			res = a * imm;
			break;
		case IMULU:
			BuildConstant();
			res = ua * (unsigned __int64)imm;
			break;
		case IMULSU:
			BuildConstant();
			res = a * (unsigned __int64)imm;
			break;
		case IDIVI:
			BuildConstant();
			res = a / imm;
			break;
		case IDIVUI:
			BuildConstant();
			res = ua / (unsigned __int64)imm;
			break;
		case IDIVSUI:
			BuildConstant();
			res = a / (unsigned __int64)imm;
			break;
		case IMODI:
			BuildConstant();
			res = a % imm;
			break;
		case IMODUI:
			BuildConstant();
			res = ua % (unsigned __int64)imm;
			break;
		case IMODSUI:
			BuildConstant();
			res = a % (unsigned __int64)imm;
			break;
		case IAND:
			BuildConstant();
			res = a & imm;
			break;
		case IOR:
			BuildConstant();
			res = a | imm;
			break;
		case IXOR:
			BuildConstant();
			res = a ^ imm;
			break;
		case IFLOAT:
			switch(ir >> 26) {
			case IFADD:
				dres.ad = opera.ad + operb.ad;
				break;
			case IFSUB:
				dres.ad = opera.ad - operb.ad;
				break;
			case IFCMP:
				if (opera.ad < operb.ad)
					res = -1;
				else if (opera.ad==operb.ad)
					res = 0;
				else
					res = 1;
				break;
			case IFMUL:
				dres.ad = opera.ad * operb.ad;
				break;
			case IFDIV:
				dres.ad = opera.ad / operb.ad;
				break;
			case IFMOV:
				dres.ad = opera.ad;
				break;
			case IFNEG:
				dres.ad = -opera.ad;
				break;
			case IFABS:
				dres.ai = opera.ai & 0x7FFFFFFFFFFFFFFFLL;
				break;
			}
			break;
		case ILB:
			BuildConstant();
			ad = a + imm;
			res = (system1->Read(ad) >> ((ad & 3)<<3)) & 0xFF;
			if (res & 0x80) res |= 0xFFFFFFFFFFFFFF00LL;
			break;
		case ILBU:
			BuildConstant();
			ad = a + imm;
			res = (system1->Read(ad) >> ((ad & 3)<<3)) & 0xFF;
			break;
		case ILC:
			BuildConstant();
			ad = a + imm;
			res = (system1->Read(ad) >> ((ad & 3)<<3)) & 0xFFFF;
			if (res & 0x8000) res |= 0xFFFFFFFFFFFF0000LL;
			break;
		case ILCU:
			BuildConstant();
			ad = a + imm;
			res = system1->Read(ad);
			res = (res >> ((ad & 3)<<3)) & 0xFFFF;
			break;
		case ILH:
			BuildConstant();
			ad = a + imm;
			res = (system1->Read(ad) >> ((ad & 3)<<3));
			if (res & 0x80000000LL) res |= 0xFFFFFFFF00000000LL;
			break;
		case ILHU:
			BuildConstant();
			ad = a + imm;
			res = (system1->Read(ad) >> ((ad & 3)<<3));
			res &= 0x00000000FFFFFFFFLL;
			break;
		case ILW:
			BuildConstant();
			ad = a + imm;
			res = system1->Read(ad);
			res |= ((unsigned __int64)system1->Read(ad+4)) << 32;
			break;
		case ILWR:
			BuildConstant();
			ad = a + imm;
			res = system1->Read(ad,1);
			res |= ((unsigned __int64)system1->Read(ad+4)) << 32;
			break;
		case ISB:
			Rt = 0;
			BuildConstant();
			ad = a + imm;
			switch(ad & 7) {
			case 0:
				system1->Write(ad,(int)regs[Rc],0x1);
				break;
			case 1:
				system1->Write(ad,(int)regs[Rc],0x2);
				break;
			case 2:
				system1->Write(ad,(int)regs[Rc],0x4);
				break;
			case 3:
				system1->Write(ad,(int)regs[Rc],0x8);
				break;
			case 4:
				system1->Write(ad,(int)regs[Rc],0x1);
				break;
			case 5:
				system1->Write(ad,(int)regs[Rc],0x2);
				break;
			case 6:
				system1->Write(ad,(int)regs[Rc],0x4);
				break;
			case 7:
				system1->Write(ad,(int)regs[Rc],0x8);
				break;
			}
			break;
		case ISC:
			Rt = 0;
			BuildConstant();
			ad = a + imm;
			switch(ad & 7) {
			case 0:
				system1->Write(ad,(int)regs[Rc],0x3);
				break;
			case 1:
				system1->Write(ad,(int)regs[Rc],0x6);
				break;
			case 2:
				system1->Write(ad,(int)regs[Rc],0xC);
				break;
			case 3:
				system1->Write(ad,(int)regs[Rc],0x8);
				break;
			case 4:
				system1->Write(ad,(int)regs[Rc],0x3);
				break;
			case 5:
				system1->Write(ad,(int)regs[Rc],0x6);
				break;
			case 6:
				system1->Write(ad,(int)regs[Rc],0xC);
				break;
			case 7:
				system1->Write(ad,(int)regs[Rc],0x8);
				break;
			}
			break;
		case ISH:
			Rt = 0;
			BuildConstant();
			ad = a + imm;
			system1->Write(ad,(int)regs[Rc],0xF);
			break;
		case ISW:
			Rt = 0;
			BuildConstant();
			ad = a + imm;
			system1->Write(ad,(int)regs[Rc],0xF);
			system1->Write(ad+4,(int)(regs[Rc]>>32),0xF);
			break;
		case ISWC:
			Rt = 0;
			BuildConstant();
			ad = a + imm;
			nn = system1->Write(ad,(int)regs[Rc],0xF,1);
			cr0 &= 0xFFFFFFEFFFFFFFFFLL;
			if (nn) cr0 |= 0x1000000000LL;
			system1->Write(ad+4,(int)(regs[Rc]>>32),0xF,0);
			break;
		case IRET:
			BuildConstant();
			a = system1->Read((unsigned int)regs[30],0);
			res = a;
			pc = a;
			regs[31] = regs[31] + imm;
			break;
		case IJAL:
			BuildConstant();
			ad = a + imm;
			res = pc + 4;
			pc = system1->Read(ad);
			break;
		case IBRK:
			switch((ir >> 30)&3) {
			case 0:	
				epc = opc|km;
				esp = regs[30];
				break;
			case 1:
				dpc = opc|km;
				dsp = regs[30];
				break;
			case 2:
				ipc = (immcnt==10) ? (opc-2)|km : (opc - immcnt * 4)|km;
				isp = regs[30];
				StatusHWI = true;
				im = true;
				break;
			}
			km = true;
			rvecno = (ir >> 17) & 0x1ff;
			ad = vbr + (((ir >> 17) & 0x1ff) << 3);
			pc = system1->Read(ad);
			break;
		case IBcc:
			Rt = 0;
			switch((ir >> 16) & 7) {
			case IBEQ:
				if (a==b)
					pc = pc - 4 + ((sir >> 21) << 1);
				break;
			case IBNE:
				if (a!=b)
					pc = pc - 4 + ((sir >> 21) << 1);
				break;
			case IBLT:
				if (a < b)
					pc = pc - 4 + ((sir >> 21) << 1);
				break;
			case IBGE:
				if (a >= b)
					pc = pc - 4 + ((sir >> 21) << 1);
				break;
			case IBLTU:
				if (ua < ub)
					pc = pc - 4 + ((sir >> 21) << 1);
				break;
			case IBGEU:
				if (ua <= ub)
					pc = pc - 4 + ((sir >> 21) << 1);
				break;
			default:
				break;
			}
			break;
		case INOP:	Rt = 0; immcnt = 0; break;
		case IIMML:
		case IIMMH:
			Rt = 0;
			immcnt = immcnt + 1;
			break;
		default: break;
		}
		//---------------------------------------------------------------------------
		// Writeback stage
		//---------------------------------------------------------------------------
		if (Rt != 0) {
			if (Rt==31 && res==0xC48EE0) {
				regs[Rt] <= res;
				printf("hi there");
			}
			regs[Rt] = res;
		}
		if (opcode != IIMML &&
			(opcode != IIMMH)
			)
			immcnt = 0;
		regs[0] = 0;
	};
