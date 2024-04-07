module fifo_tb ();
	// Constants
	localparam int DATA_WIDTH = 8;
	localparam int FIFO_DEPTH = 2;

	// Declerations
	logic                            clk        = 1'b0        ;
	logic                            rst_n      = 1'b1        ;
	logic                            write      = 1'b0        ;
	logic [          DATA_WIDTH-1:0] write_data = '{default:1};
	logic                            read       = 1'b0        ;
	logic [          DATA_WIDTH-1:0] read_data                ;
	logic [$clog2(FIFO_DEPTH+1)-1:0] fill_level               ;
	logic                            full                     ;
	logic                            empty                    ;

	// DUT
	fifo #(
		.DATA_WIDTH(DATA_WIDTH),
		.FIFO_DEPTH(FIFO_DEPTH)
	) i_fifo (
		.clk       (clk       ),
		.rst_n     (rst_n     ),
		.write     (write     ),
		.write_data(write_data),
		.read      (read      ),
		.read_data (read_data ),
		.fill_level(fill_level),
		.full      (full      ),
		.empty     (empty     )
	);

	// Stimulus
	initial begin
		@(negedge rst_n);
		@(posedge clk);

		write <= 1'b1;
		repeat (2) @(posedge clk);
		write_data <= 1;
		read <= 1'b1;
		@(posedge clk);
		write_data <= 2;

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