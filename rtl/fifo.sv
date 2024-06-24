import fifo_pack::*;
import generic_func_pack::*;

// FIFO_DEPTH must be a power of 2
module fifo #(
	parameter int 		FIFO_DEPTH,
	parameter fl_type_e FL_MODE, // Fill-level implementation type. Can't be CNTR whilst IN_ERROR is enabled
	parameter bit 		STORE_FORWARD,
	parameter bit 		IN_ERROR
) (
	// General
	input  logic                            clk       , // Clock
	input  logic                            rst_n     , // Asynchronous reset active low
	// Write Interface
	avalon_st_if.slave                      write     ,
	input  logic                            in_error  , // Rollback request
	// Read Interface
	avalon_st_if.master                     read      ,
	// Indications
	output logic [$clog2(FIFO_DEPTH+1)-1:0] fill_level, // Ranges from 0 up to FIFO_DEPTH including! (thus the +1)
	output logic                            full      ,
	output logic                            empty
);
	// Assertions
	initial begin
		if (write.DATA_WIDTH != read.DATA_WIDTH) begin
			$error("write/read interface data width mismatch!");
			$fatal();
		end

		if (!is_pow2(FIFO_DEPTH)) begin
			$error("FIFO_DEPTH is not a power of 2!");
			$fatal();
		end

		if (FL_MODE == CNTR && IN_ERROR) begin
			$error("FL_MODE can't be set to CNTR whilst IN_ERROR is set!");
			$fatal();
		end
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

	logic                 rb_cmd;  // Enforced rollback command
	logic [PTR_WIDTH-1:0] rb_addr; // Address to load on rollback

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

	// vld/rdy equivalent
	assign write.rdy = ~full;
	assign read.vld  = ~empty;

	// Write/Read pointer counters
	generate
		always_ff @(posedge clk or negedge rst_n) begin : proc_write_ptr
			if(~rst_n) begin
				write_ptr <= {PTR_WIDTH{1'b0}};
			end else begin
				if (IN_ERROR && rb_cmd) // TODO: Check if synthesized correctly 
					write_ptr <= rb_addr; // Load rollback value
				else
					write_ptr <= write_ptr + write_cmd; // This style of code relies on the natural wrap-around of counters with power-of-2 count size
			end
		end

		always_ff @(posedge clk or negedge rst_n) begin : proc_read_ptr
			if(~rst_n) begin
				read_ptr <= {PTR_WIDTH{1'b0}};
			end else begin
				read_ptr <= read_ptr + read_cmd;
			end
		end
	endgenerate


	// Fill-level and full/empty calculation
	generate
		// Record last operation (read/write), to differentiate empty/full state
		logic last_op_write;
		logic ptrs_match;

		always_ff @(posedge clk or negedge rst_n) begin : proc_last_op_write
			if(~rst_n) begin
				last_op_write <= 1'b0;
			end else begin
				if (read_cmd)
					last_op_write <= 1'b0;
				else if (write_cmd)
					last_op_write <= 1'b1;
			end
		end

		always_comb begin : proc_full_empty_calc
			ptrs_match = (read_ptr == write_ptr);

			full  = (ptrs_match & last_op_write);
			empty = (ptrs_match & ~last_op_write);
		end

		if (FL_MODE == CNTR) begin
			always_ff @(posedge clk or negedge rst_n) begin : proc_fill_level
				if(~rst_n) begin
					fill_level <= {FILL_LVL_WIDTH{1'b0}};
				end else begin
					// We can be assured fill_level will stay in (0 to FIFO_DEPTH) range, as 'write_cmd' and 'read_cmd' are enforced by full and empty
					fill_level <= fill_level + (write_cmd - read_cmd);
				end
			end
		end else if (FL_MODE == CALC) begin
			logic msg_bit;
			logic [PTR_WIDTH-1:0] ptr_diff;

			always_comb begin : proc_fill_level
				msg_bit  = full;
				ptr_diff = (write_ptr - read_ptr);

				fill_level = {msg_bit, ptr_diff}; // Relies on pow2-cntr constraint
			end
		end else if (FL_MODE == NONE) begin
			assign fill_level = {FILL_LVL_WIDTH{1'b0}};
		end
	endgenerate

	// Add-on logic (s&f and rollback)
	generate
		typedef struct {
			logic [PTR_WIDTH-1:0] ptr;
			logic                 vld;
		} vld_ptr;

		// Store-and-Forward functionality
		if (STORE_FORWARD) begin
			vld_ptr last_eop;

			always_ff @(posedge clk or negedge rst_n) begin : proc_last_eop
				if(~rst_n) begin
					last_eop.ptr <= {PTR_WIDTH{1'b0}};
					last_eop.vld <= 1'b0;
				end else begin
					if (write_cmd & write.eop) begin
						last_eop.ptr <= write_ptr;
						last_eop.vld <= 1'b1;
					end else if (read_cmd & (read_ptr == last_eop.ptr)) begin
						last_eop.vld <= 1'b0;
					end
				end
			end

			// read commands are valid for transactions only. read.rdy is the 'read' request
			assign read_cmd = read.rdy & read.vld & last_eop.vld; // Blocks reading until we have full packet
		end else begin
			assign read_cmd = read.rdy & read.vld;
		end

		if (IN_ERROR) begin
			vld_ptr last_sop;
			logic read_sop;
			logic ignore_word;
			
			// We can simply ignore 1-word erroneous packets. Simplifying rollback implementation
			assign ignore_word = write.vld & write.rdy & write.sop & write.eop & in_error;

			always_ff @(posedge clk or negedge rst_n) begin : proc_last_sop
				if(~rst_n) begin
					last_sop.ptr <= {PTR_WIDTH{1'b0}};
					last_sop.vld <= 1'b0;
				end else begin
					if (write_cmd & write.sop) begin
						last_sop.ptr <= write_ptr;
						last_sop.vld <= 1'b1;
					end else if (read_sop) begin
						last_sop.vld <= 1'b0;
					end
				end
			end
			assign read_sop = (read_cmd & (read_ptr == last_sop.ptr));

			// Rollback is firstly defined as an 'in_error' request arriving at 'eop'
			// The second operand blocks rollback if packet begun to be read
			assign rb_cmd  = (in_error & write.eop) && (last_sop.vld & ~read_sop);
			assign rb_addr = last_sop.ptr;

			// write commands are valid for transactions only. write.vld is the 'write' request
			assign write_cmd = write.vld & write.rdy & ~ignore_word & ~rb_cmd;
		end else begin
			assign write_cmd = write.vld & write.rdy;
		end

	endgenerate
endmodule : fifo