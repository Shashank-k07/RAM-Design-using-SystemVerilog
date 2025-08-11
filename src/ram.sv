module ram(reset, clock, wr_data, rd_data, rd_en, wr_en, addr);
	input reset, rd_en, wr_en, clock;
	input[7:0]wr_data;
	input[6:0]addr;
	output reg[7:0]rd_data;
	reg[7:0]  mem[127:0];
	integer i;
	always@(posedge clock) begin
		if(reset==1) begin
			rd_data=0;
			for(i=0;i<128;i=i+1)begin
				mem[i]=0;
			end
		end
		else begin
			if(wr_en==1) begin
				mem[addr] = wr_data;
			end
			if(rd_en==1) begin
				rd_data = mem[addr];
			end

		end
	end
endmodule

class tb;
	randc bit reset, rd_en, wr_en;
	randc bit[7:0]wr_data;
	randc bit[6:0]addr;
	constraint c1{
		addr==111;
		(reset==1)->(wr_en==0);
		(reset==1)->(rd_en==0);
		}
		endclass
interface ram_inf(input bit clock);
	bit reset, rd_en, wr_en;
	bit[7:0]rd_data; 
	bit[7:0]wr_data;
	bit[6:0]addr;
endinterface

class common;
	static mailbox mb = new();
	static virtual ram_inf vif;
endclass

class gen;
	tb p;
	task t1;
		p = new();
		p.randomize();
		common::mb.put(p);
	endtask
endclass

class bfm;
	tb p;
	task t2;
		p = new();
		common::mb.get(p);
		common::vif.wr_data = p.wr_data;
		common::vif.wr_en = p.wr_en;
		common::vif.rd_en  = p.rd_en;
		common::vif.reset = p.reset;
		common::vif.addr = p.addr;
	endtask
endclass


module test;
	bit clock;
	gen a = new();
	bfm b = new();
	initial begin
		clock = 0;
		forever #5 clock = ~clock;
	end
	ram_inf pvif(clock);
	ram dut(.clock(pvif.clock),  .reset(pvif.reset), .wr_en(pvif.wr_en), .rd_en(pvif.rd_en), .wr_data(pvif.wr_data), .rd_data(pvif.rd_data), .addr(pvif.addr));
	initial begin
		common::vif = pvif;
		repeat(10) begin
		a.t1;
		b.t2;
		@(posedge clock);
		end
		$finish;
	end	
endmodule
