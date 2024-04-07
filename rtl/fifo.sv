module fifo #(
	parameter int DATA_WIDTH,
	parameter int FIFO_DEPTH // Must be a power of 2
) (
	// General
	input  logic                            clk       , // Clock
	input  logic                            rst_n     , // Asynchronous reset active low
	// Write Interface
	input  logic                            write     , // Write command will be ignored when full is asserted
	input  logic [          DATA_WIDTH-1:0] write_data,
	// Read Interface
	input  logic                            read      , // Read command will be ignored when empty is asserted
	output logic [          DATA_WIDTH-1:0] read_data ,
	// Indications
	output logic [$clog2(FIFO_DEPTH+1)-1:0] fill_level, // Ranges from 0 up to FIFO_DEPTH including! (thus the +1)
	output logic                            full      ,
	output logic                            empty
);
	// Assertions
	initial begin
		assert (is_pow2(FIFO_DEPTH));
			else $error("FIFO_DEPTH is not a power of 2!");
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

	dram #(
		.DATA_WIDTH(DATA_WIDTH),
		.MEM_DEPTH (FIFO_DEPTH)
	) i_dram (
		.clk       (clk       ),
		.rst_n     (rst_n     ),
		.write     (write_cmd ),
		.write_data(write_data),
		.write_addr(write_ptr ),
		.read_data (read_data ),
		.read_addr (read_ptr  )
	);

	// Enforce write/read pointers
	assign write_cmd = write & ~full;
	assign read_cmd  = read & ~empty;

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

endmodule : fifo



module dram #(
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
		assert (is_pow2(MEM_DEPTH));
			else $error("MEM_DEPTH is not a power of 2!");
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

endmodule : dram



function bool is_pow2(int num);
	return num == (2 ** $clog2(num));
endfunction : is_pow2