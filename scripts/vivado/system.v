`timescale 1 ns / 1 ps

// uncomment this to allow fault injection with mutants
//`define TMR_INJECT_ERR

module system (
	input            clk,
	input            resetn,
	output           trap,
	output reg [7:0] out_byte,
	output reg       out_byte_en
);
	// set this to 0 for better timing but less performance/MHz
	parameter FAST_MEMORY = 1;

	// 4096 32bit words = 16kB memory
	parameter MEM_SIZE = 4096;

	wire mem_valid;
	wire mem_instr;
	reg mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	reg [31:0] mem_rdata;

	wire mem_la_read;
	wire mem_la_write;
	wire [31:0] mem_la_addr;
	wire [31:0] mem_la_wdata;
	wire [3:0] mem_la_wstrb;

	(*mark_debug = "true"*)
	wire [ 2:0] tmr_errors [14];
	wire [ 2:0] tmr_inject [14];

	//picorv32 picorv32_core (
	picorv32_tmr picorv32_core (
		.clk         (clk         ),
		.resetn      (resetn      ),
		.trap        (trap        ),
		.mem_valid   (mem_valid   ),
		.mem_instr   (mem_instr   ),
		.mem_ready   (mem_ready   ),
		.mem_addr    (mem_addr    ),
		.mem_wdata   (mem_wdata   ),
		.mem_wstrb   (mem_wstrb   ),
		.mem_rdata   (mem_rdata   ),
		.mem_la_read (mem_la_read ),
		.mem_la_write(mem_la_write),
		.mem_la_addr (mem_la_addr ),
		.mem_la_wdata(mem_la_wdata),
		.mem_la_wstrb(mem_la_wstrb),
    `ifdef TMR_INJECT_ERR
        .tmr_inject  (tmr_inject),
    `endif
		.tmr_errors  (tmr_errors)

	);

	reg [31:0] memory [0:MEM_SIZE-1];
	initial $readmemh("firmware.hex", memory);

	reg [31:0] m_read_data;
	reg m_read_en;

    // Simulate Faults with Mutants signals
    assign tmr_inject[0]  = 0;    //trap
    assign tmr_inject[1]  = 0;    //mem_valid & mem_instr & mem_wstrb
    assign tmr_inject[2]  = 0;    //mem_addr
    assign tmr_inject[3]  = 0;    //mem_wdata
    assign tmr_inject[4]  = 0;    //mem_la_read & mem_la_write & mem_la_wstrb
    assign tmr_inject[5]  = 0;    //mem_la_addr
    assign tmr_inject[6]  = 0;    //mem_la_wdata
    assign tmr_inject[7]  = 0;    //pcpi_valid
    assign tmr_inject[8]  = 0;    //pcpi_insn
    assign tmr_inject[9]  = 0;    //pcpi_rs1
    assign tmr_inject[10] = 0;    //pcpi_rs2
    assign tmr_inject[11] = 0;    //eoi
    assign tmr_inject[12] = 0;    //trace_valid
    assign tmr_inject[13] = 0;    //trace_data

	generate if (FAST_MEMORY) begin
		always @(posedge clk) begin
			mem_ready <= 1;
			out_byte_en <= 0;
			mem_rdata <=    (mem_la_read && mem_la_addr == 32'h4000_0010) ? tmr_errors[0] :
			                (mem_la_read && mem_la_addr == 32'h4000_0014) ? tmr_errors[1] :
							(mem_la_read && mem_la_addr == 32'h4000_0018) ? tmr_errors[2] :
							(mem_la_read && mem_la_addr == 32'h4000_001C) ? tmr_errors[3] :
							(mem_la_read && mem_la_addr == 32'h4000_0020) ? tmr_errors[4] :
							(mem_la_read && mem_la_addr == 32'h4000_0024) ? tmr_errors[5] :
							(mem_la_read && mem_la_addr == 32'h4000_0028) ? tmr_errors[6] :
							(mem_la_read && mem_la_addr == 32'h4000_002C) ? tmr_errors[7] :
							(mem_la_read && mem_la_addr == 32'h4000_0030) ? tmr_errors[8] :
							(mem_la_read && mem_la_addr == 32'h4000_0034) ? tmr_errors[9] :
							(mem_la_read && mem_la_addr == 32'h4000_0038) ? tmr_errors[10] :
							(mem_la_read && mem_la_addr == 32'h4000_003C) ? tmr_errors[11] :
							(mem_la_read && mem_la_addr == 32'h4000_0040) ? tmr_errors[12] :
							(mem_la_read && mem_la_addr == 32'h4000_0044) ? tmr_errors[13] :
							(mem_la_read && mem_la_addr == 32'h4000_0048) ? 8 :
							memory[mem_la_addr >> 2];
			if (mem_la_write && (mem_la_addr >> 2) < MEM_SIZE) begin
				if (mem_la_wstrb[0]) memory[mem_la_addr >> 2][ 7: 0] <= mem_la_wdata[ 7: 0];
				if (mem_la_wstrb[1]) memory[mem_la_addr >> 2][15: 8] <= mem_la_wdata[15: 8];
				if (mem_la_wstrb[2]) memory[mem_la_addr >> 2][23:16] <= mem_la_wdata[23:16];
				if (mem_la_wstrb[3]) memory[mem_la_addr >> 2][31:24] <= mem_la_wdata[31:24];
			end
			else
			if (mem_la_write && mem_la_addr == 32'h1000_0000) begin
				out_byte_en <= 1;
				out_byte <= mem_la_wdata;
			end
		end
	end else begin
		always @(posedge clk) begin
			m_read_en <= 0;
			mem_ready <= mem_valid && !mem_ready && m_read_en;

			m_read_data <= memory[mem_addr >> 2];
			mem_rdata <= m_read_data;

			out_byte_en <= 0;

			(* parallel_case *)
			case (1)
				mem_valid && !mem_ready && !mem_wstrb && (mem_addr >> 2) < MEM_SIZE: begin
					m_read_en <= 1;
				end
				mem_valid && !mem_ready && |mem_wstrb && (mem_addr >> 2) < MEM_SIZE: begin
					if (mem_wstrb[0]) memory[mem_addr >> 2][ 7: 0] <= mem_wdata[ 7: 0];
					if (mem_wstrb[1]) memory[mem_addr >> 2][15: 8] <= mem_wdata[15: 8];
					if (mem_wstrb[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
					if (mem_wstrb[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
					mem_ready <= 1;
				end
				mem_valid && !mem_ready && |mem_wstrb && mem_addr == 32'h1000_0000: begin
					out_byte_en <= 1;
					out_byte <= mem_wdata;
					mem_ready <= 1;
				end
			endcase
		end
	end endgenerate
endmodule
