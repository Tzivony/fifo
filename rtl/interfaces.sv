interface dvr_if #(parameter DATA_WIDTH) ();
	logic [DATA_WIDTH-1:0] data;
	logic                  vld ;
	logic                  rdy ;

	modport master (
		output data,
		output vld,
		input  rdy
	);

	modport slave (
		input  data,
		input  vld,
		output rdy
	);
endinterface : dvr_if


interface avalon_st_if #(parameter DATA_WIDTH_IN_BYTES) ();
	localparam int DATA_WIDTH = DATA_WIDTH_IN_BYTES * $bits(byte);
	localparam int META_WIDTH = $clog2(DATA_WIDTH) + 2; // sizeof empty, sop and eop
	localparam int CTRL_WIDTH = 2; // sizeof vld and rdy

	logic [        DATA_WIDTH-1:0] data ;
	logic [$clog2(DATA_WIDTH)-1:0] empty;
	logic                          sop  ;
	logic                          eop  ;
	logic                          vld  ;
	logic                          rdy  ;

	modport master (
		output data,
		output empty,
		output sop,
		output eop,
		output vld,
		input  rdy
	);

	modport slave (
		input  data,
		input  empty,
		input  sop,
		input  eop,
		input  vld,
		output rdy
	);
endinterface : avalon_st_if