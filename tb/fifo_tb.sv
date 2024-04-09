module fifo_tb ();
	// Constants
	localparam int DATA_WIDTH_IN_BYTES = 1;
	localparam int FIFO_DEPTH = 2;

	// Declerations
	logic clk   = 1'b0;
	logic rst_n = 1'b1;
	avalon_st_if #(.DATA_WIDTH_IN_BYTES(DATA_WIDTH_IN_BYTES)) write ();
	avalon_st_if #(.DATA_WIDTH_IN_BYTES(DATA_WIDTH_IN_BYTES)) read  ();
	logic [$clog2(FIFO_DEPTH+1)-1:0] fill_level;
	logic                            full      ;
	logic                            empty     ;

	// DUT
	fifo #(
		.FIFO_DEPTH(FIFO_DEPTH)
	) i_fifo (
		.clk       (clk       ),
		.rst_n     (rst_n     ),
		.write     (write     ),
		.read      (read      ),
		.fill_level(fill_level),
		.full      (full      ),
		.empty     (empty     )
	);


	// Stimulus
	initial begin
		write.data = '{default:1};
		write.vld = 1'b0;
		write.sop = 1'b0;
		write.eop = 1'b0;
		write.empty = '{default:0};
		read.rdy = 1'b0;

		@(negedge rst_n);
		@(posedge clk);

		write.vld <= 1'b1;
		repeat (2) @(posedge clk);
		write.data <= 1;
		read.rdy <= 1'b1;
		@(posedge clk);
		write.data <= 2;

		repeat (3) @(posedge clk);
		write.vld <= 1'b0;

		#10000;
	end

	// Clock
	always #0.5 clk = ~clk;

	// Reset
	initial begin
		@(posedge clk);
		rst_n <= 1'b0;
		@(posedge clk);
		rst_n <= 1'b1;
	end

endmodule : fifo_tb