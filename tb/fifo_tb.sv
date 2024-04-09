module fifo_tb ();
	// Constants
	localparam int DATA_WIDTH_IN_BYTES = 1;
	localparam int FIFO_DEPTH = 4;

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
		.FIFO_DEPTH(FIFO_DEPTH),
		.STORE_FORWARD(1'b1)
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

		@(posedge rst_n);

		write.vld <= 1'b1; // Note that this creates an invalid interface (valid out of packet)
		repeat (2) @(posedge clk);
		write.data <= 1;
		read.rdy <= 1'b1;
		@(posedge clk);
		write.data <= 2;

		repeat (3) @(posedge clk);
		write.vld <= 1'b0;

		#10000;
	end

	initial begin
		@(posedge rst_n);
		@(posedge clk);

		write.sop = 1'b1;
		@(posedge clk);
		write.sop = 1'b0;

		@(posedge clk);

		write.eop = 1'b1;
		@(posedge clk);
		write.eop = 1'b0;
	end


	// Clock & Reset
	always #0.5 clk = ~clk;

	initial begin
		@(posedge clk);
		rst_n <= 1'b0;
		@(posedge clk);
		rst_n <= 1'b1;
	end

endmodule : fifo_tb