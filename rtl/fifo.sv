import generic_func_pack::*;


module fifo #(
	parameter int DATA_WIDTH,
	parameter int FIFO_DEPTH // Must be a power of 2
) (
	// General
	input  logic                            clk       , // Clock
	input  logic                            rst_n     , // Asynchronous reset active low
	// Write Interface
	dvr_if.master                           write     ,
	// Read Interface
	dvr_if.slave                            read      ,
	// Indications
	output logic [$clog2(FIFO_DEPTH+1)-1:0] fill_level, // Ranges from 0 up to FIFO_DEPTH including! (thus the +1)
	output logic                            full      ,
	output logic                            empty
);
	// Assertions
	initial begin
		if (!is_pow2(FIFO_DEPTH))
			$error("FIFO_DEPTH is not a power of 2!");
	end

	// Constants
	localparam int PTR_WIDTH      = $clog2(FIFO_DEPTH)  ;
	localparam int FILL_LVL_WIDTH = $clog2(FIFO_DEPTH+1);

	// Declerations

	// Enforced write/read commands
	logic write_cmd;
	logic read_cmd ;

	// write/read pointers
	logic [PTR_WIDTH-1:0] write_ptr;
	logic [PTR_WIDTH-1:0] read_ptr ;


	// Logic

	sdp_ram #(
		.DATA_WIDTH(DATA_WIDTH),
		.MEM_DEPTH (FIFO_DEPTH)
	) i_sdp_ram (
		.clk       (clk       ),
		.rst_n     (rst_n     ),
		.write     (write_cmd ),
		.write_data(write.data),
		.write_addr(write_ptr ),
		.read_data (read.data ),
		.read_addr (read_ptr  )
	);

	// write/read commands are valid for transactions only
	assign write_cmd = write.vld & write.rdy; // write.vld is the 'write' request
	assign read_cmd  = read.rdy & read.vld; // read.rdy is the 'read' request

	always_ff @(posedge clk or negedge rst_n) begin : proc_ptr_cntrs
		if(~rst_n) begin
			write_ptr <= {DATA_WIDTH{1'b0}};
			read_ptr  <= {DATA_WIDTH{1'b0}};
		end else begin
			// This style of code relies on the natural wrap-around of counters with power-of-2 count size
			write_ptr <= write_ptr + write_cmd;
			read_ptr  <= read_ptr + read_cmd;
		end
	end

	always_ff @(posedge clk or negedge rst_n) begin : proc_fill_level
		if(~rst_n) begin
			fill_level <= {FILL_LVL_WIDTH{1'b0}};
		end else begin
			// We can be assured fill_level will stay in (0 to FIFO_DEPTH) range, as 'write_cmd' and 'read_cmd' are enforced by full and empty
			fill_level <= fill_level + (write_cmd - read_cmd);
		end
	end

	// Calc full/empty
	assign full  = (fill_level == FIFO_DEPTH);
	assign empty = (fill_level == 0);

	// vld/rdy equivalent
	assign write.rdy = ~full;
	assign read.vld  = ~empty;

endmodule : fifo