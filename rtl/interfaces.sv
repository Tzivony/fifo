interface dvr_if #(parameter DATA_WIDTH) ();
	logic [DATA_WIDTH-1:0] data;
	logic                  vld ;
	logic                  rdy ;

	modport master (
		output data,
		output vld,
		input rdy
	);

	modport slave (
		input data,
		input vld,
		output rdy
	);
endinterface : dvr_if