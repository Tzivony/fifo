import generic_func_pack::*;

// This Avalon-ST FIFO relies on valid interface.
module fifo #(
	parameter int FIFO_DEPTH, // FIFO_DEPTH must be a power of 2
	parameter bit STORE_FORWARD = 1'b0, // Rather or not to implement store-and-forward functionality
	parameter bit ROLLBACK      = 1'b0  // Rather or not to implement roll-back functionality
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
	// Store-and-Forward
	logic sf_en; // Enable signal outcomming from the store-and-forward functionality. Used to block reading of unwhole messages

	// Rollback
	logic                      rb_en          ; // Enable signal outcomming from the roll-back functionality. Used to ignore erronous 1-word messages
	logic                      rb_cmd         ; // roll-back command to reload write_ptr and fill_level
	logic [     PTR_WIDTH-1:0] prev_write_ptr ;
	logic [FILL_LVL_WIDTH-1:0] prev_fill_level;

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

	// read/write commands are valid for transactions only
	// write.vld behaves as the 'write' request, and equivalently, read.rdy as the 'read' request
	assign read_cmd  = read.rdy & read.vld;
	assign write_cmd = (write.vld & write.rdy) & rb_en; // Allowing writing with consideration of the roll-back enable

	// write/read address pointers
	always_ff @(posedge clk or negedge rst_n) begin : proc_ptr_cntrs
		if(~rst_n) begin
			write_ptr <= {PTR_WIDTH{1'b0}};
			read_ptr  <= {PTR_WIDTH{1'b0}};
		end else begin
			read_ptr <= read_ptr + read_cmd; // This style of code relies on the natural wrap-around of counters with power-of-2 count size

			if (rb_cmd)
				write_ptr <= prev_write_ptr;
			else
				write_ptr <= write_ptr + write_cmd; // -"-
		end
	end

	// Fill-level
	always_ff @(posedge clk or negedge rst_n) begin : proc_fill_level
		if(~rst_n) begin
			fill_level <= {FILL_LVL_WIDTH{1'b0}};
		end else begin
			if (rb_cmd) begin
				fill_level <= prev_fill_level;
			end else begin
				// We can be assured fill_level will stay in (0 to FIFO_DEPTH) range, as 'write_cmd' and 'read_cmd' are enforced by full and empty
				fill_level <= fill_level + (write_cmd - read_cmd);
			end
		end
	end

	// Calc full/empty
	assign full  = (fill_level == FIFO_DEPTH);
	assign empty = (fill_level == 0);

	// vld/rdy equivalent
	assign write.rdy = ~full;
	assign read.vld  = (~empty) & sf_en; // Allowing reading with consideration of the store-and-forward enable


	// Add-on logic
	generate
		logic sop_in, eop_in, eop_out;

		always_comb begin : proc_enforce_signals
			// We want to take into account only valid signals (i.e. during a transaction)
			sop_in  = write.sop & write_cmd;
			eop_in  = write.eop & write_cmd;
			eop_out = read.eop  & read_cmd ;
		end

		// Store-and-forward
		if (STORE_FORWARD) begin
			_store_forward_addon #(
				.FILL_LVL_WIDTH(FILL_LVL_WIDTH)
			) i__store_forward_addon (
				.clk    (clk    ),
				.rst_n  (rst_n  ),
				.eop_in (eop_in ),
				.eop_out(eop_out),
				.sf_en  (sf_en  )
			);
		end else begin
			assign sf_en = 1'b1;
		end

		// Rollback
		if (ROLLBACK) begin
			_rollback_addon #(
				.STORE_FORWARD (STORE_FORWARD ),
				.PTR_WIDTH     (PTR_WIDTH     ),
				.FILL_LVL_WIDTH(FILL_LVL_WIDTH)
			) i__rollback_addon (
				.clk            (clk            ),
				.rst_n          (rst_n          ),
				.sop_in         (sop_in         ),
				.eop_in         (eop_in         ),
				.read_cmd       (read_cmd       ),
				.in_error       (in_error       ),
				.write_ptr      (write_ptr      ),
				.read_ptr       (read_ptr       ),
				.fill_level     (fill_level     ),
				.rb_en          (rb_en          ),
				.rb_cmd         (rb_cmd         ),
				.prev_write_ptr (prev_write_ptr ),
				.prev_fill_level(prev_fill_level)
			);
		end else begin
			assign rb_en           = 1'b1;
			assign rb_cmd          = 1'b0;
			assign prev_write_ptr  = {PTR_WIDTH{1'b0}};
			assign prev_fill_level = {FILL_LVL_WIDTH{1'b0}};
		end
	endgenerate
endmodule : fifo



// Auxillary sub-modules
module _store_forward_addon #(parameter int FILL_LVL_WIDTH) (
	input  logic clk    , // Clock
	input  logic rst_n  , // Asynchronous reset active low
	input  logic eop_in ,
	input  logic eop_out,
	output logic sf_en
);
	// Declerations
	logic [FILL_LVL_WIDTH-1:0] eop_cnt; // Worst-case - each word is a packet

	// Logic

	always_ff @(posedge clk or negedge rst_n) begin : proc_eop_cnt
		if(~rst_n) begin
			eop_cnt <= {FILL_LVL_WIDTH{1'b0}};
		end else begin
			eop_cnt <= eop_cnt + (eop_in - eop_out);
		end
	end

	// Allowing read only after there's at least one whole packet in the system
	assign sf_en = (eop_cnt > 0);

endmodule : _store_forward_addon


module _rollback_addon #(
	parameter int STORE_FORWARD,
	parameter int PTR_WIDTH,
	parameter int FILL_LVL_WIDTH
) (
	input  logic                      clk            , // Clock
	input  logic                      rst_n          , // Asynchronous reset active low
	input  logic                      sop_in         ,
	input  logic                      eop_in         ,
	input  logic                      read_cmd       ,
	input  logic                      in_error       ,
	input  logic [     PTR_WIDTH-1:0] write_ptr      ,
	input  logic [     PTR_WIDTH-1:0] read_ptr       ,
	input  logic [FILL_LVL_WIDTH-1:0] fill_level     ,
	output logic                      rb_en          ,
	output logic                      rb_cmd         ,
	output logic [     PTR_WIDTH-1:0] prev_write_ptr ,
	output logic [FILL_LVL_WIDTH-1:0] prev_fill_level
);
	// Declerations
	logic cant_drop; // Indicates we can't drop the message, as reading it already begun

	// Logic

	// We can simply ignore 1-word erronous messages.
	// This also makes the rb_cmd functionality easier to implement (it'll be considered an edge-case bug without it here)
	assign rb_en = ~(sop_in & eop_in & in_error);

	// Saving previous fill-level and write pointer values for roll-back functionality
	always_ff @(posedge clk or negedge rst_n) begin : proc_save_prev
		if(~rst_n) begin
			prev_write_ptr  <= {PTR_WIDTH{1'b0}};
			prev_fill_level <= {FILL_LVL_WIDTH{1'b0}};
		end else begin
			if (sop_in) begin
				prev_write_ptr  <= write_ptr;
				prev_fill_level <= fill_level;
			end
		end
	end

	// Calc cant_drop
	generate
		if (STORE_FORWARD) begin
			assign cant_drop = 1'b0; // We can always accept in_error in store-and-forward mode
		end else begin
			// SRFF
			always_ff @(posedge clk or negedge rst_n) begin : proc_cant_drop
				if(~rst_n) begin
					cant_drop <= 1'b0;
				end else begin
					// This condition means we begun reading the current incomming message. Thus, it's not allowed to be dropped
					if ((prev_write_ptr == read_ptr) & read_cmd) begin
						cant_drop <= 1'b1;
					end
					if (eop_in) begin
						cant_drop <= 1'b0;
					end
				end
			end
		end
	endgenerate

	assign rb_cmd = (~cant_drop) & in_error & eop_in;

endmodule : _rollback_addon