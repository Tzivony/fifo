import generic_func_pack::*;


module fifo #(
	parameter int FIFO_DEPTH, // FIFO_DEPTH must be a power of 2
	parameter bit STORE_FORWARD = 1'b0  // Rather or not to implement store-and-forward functionality
) (
	// General
	input  logic                            clk       , // Clock
	input  logic                            rst_n     , // Asynchronous reset active low
	// Write Interface
	avalon_st_if.slave                     	write     ,
	// Read Interface
	avalon_st_if.master                     read      ,
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
	localparam int FIFO_DATA_WIDTH = write.DATA_WIDTH + write.META_WIDTH; // Note we include both original, and meta data
	localparam int PTR_WIDTH       = $clog2(FIFO_DEPTH)                 ;
	localparam int FILL_LVL_WIDTH  = $clog2(FIFO_DEPTH+1)               ;

	// Declerations

	// Data saved in fifo (original data + interface meta-data)
	logic [(FIFO_DATA_WIDTH)-1:0] write_data;
	logic [(FIFO_DATA_WIDTH)-1:0] read_data ;

	// Enforced write/read commands
	logic write_cmd;
	logic read_cmd ;

	// write/read pointers
	logic [PTR_WIDTH-1:0] write_ptr;
	logic [PTR_WIDTH-1:0] read_ptr ;

	// Add-ons
	logic snf_en; // Enable signal outcomming from the store-and-forward functionality

	// Logic

	sdp_ram #(
		.DATA_WIDTH(FIFO_DATA_WIDTH),
		.MEM_DEPTH (FIFO_DEPTH     )
	) i_sdp_ram (
		.clk       (clk       ),
		.rst_n     (rst_n     ),
		.write     (write_cmd ),
		.write_data(write_data),
		.write_addr(write_ptr ),
		.read_data (read_data ),
		.read_addr (read_ptr  )
	);

	// Concatenate / de-concatenate write/read data
	assign write_data = {write.data, write.empty, write.sop, write.eop};
	assign {read.data, read.empty, read.sop, read.eop} = read_data;

	// write/read commands are valid for transactions only
	assign write_cmd = write.vld & write.rdy; // write.vld is the 'write' request
	assign read_cmd  = read.rdy & read.vld; // read.rdy is the 'read' request

	// write/read address pointers
	always_ff @(posedge clk or negedge rst_n) begin : proc_ptr_cntrs
		if(~rst_n) begin
			write_ptr <= {PTR_WIDTH{1'b0}};
			read_ptr  <= {PTR_WIDTH{1'b0}};
		end else begin
			// This style of code relies on the natural wrap-around of counters with power-of-2 count size
			write_ptr <= write_ptr + write_cmd;
			read_ptr  <= read_ptr + read_cmd;
		end
	end

	// Fill-level
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
	assign read.vld  = (~empty) & snf_en; // Allowing reading with consideration of the store-and-forward enable



	// Add-on logic

	// Store-and-forward
	generate
		if (STORE_FORWARD) begin
			logic [FILL_LVL_WIDTH-1:0] eop_cnt; // Worst-case - each word is a packet
			logic                      eop_in, eop_out;

			// We want to count only valid eops (i.e. during a transaction)
			assign eop_in  = write.eop & write_cmd;
			assign eop_out = read.eop & read_cmd;

			always_ff @(posedge clk or negedge rst_n) begin : proc_eop_cnt
				if(~rst_n) begin
					eop_cnt <= {FILL_LVL_WIDTH{1'b0}};
				end else begin
					eop_cnt <= eop_cnt + (eop_in - eop_out);
				end
			end

			// Allowing read only after there's at least one whole packet in the system
			assign snf_en = (eop_cnt > 0);

		end else begin
			assign snf_en = 1'b1;
		end
	endgenerate
endmodule : fifo