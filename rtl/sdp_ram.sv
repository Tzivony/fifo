import generic_func_pack::*;


/*
This simple-dual-port RAM will be utilized over common resources
i.e. we implement a DRAM here, or a 'Distributed RAM'.
Opposed to, for example, over a BRAMs (Block RAMs)
*/
module sdp_ram #(
	parameter int DATA_WIDTH,
	parameter int MEM_DEPTH // Must be a power of 2
) (
	input  logic                         clk       , // Clock
	input  logic                         rst_n     , // Asynchronous reset active low
	// Write Interface
	input  logic                         write     ,
	input  logic [       DATA_WIDTH-1:0] write_data,
	input  logic [$clog2(MEM_DEPTH)-1:0] write_addr,
	// Read Interface
	output logic [       DATA_WIDTH-1:0] read_data ,
	input  logic [$clog2(MEM_DEPTH)-1:0] read_addr
);
	// Assertions
	initial begin
		if (!is_pow2(MEM_DEPTH))
			$error("MEM_DEPTH is not a power of 2!");
	end

	// Declerations

	logic [DATA_WIDTH-1:0] reg_array[MEM_DEPTH];


	// Logic

	always_ff @(posedge clk or negedge rst_n) begin : proc_reg_array
		if(~rst_n) begin
			reg_array <= '{MEM_DEPTH{DATA_WIDTH'(0)}};
		end else begin
			if (write) begin
				reg_array[write_addr] <= write_data;
			end
		end
	end

	assign read_data = reg_array[read_addr];

endmodule : sdp_ram