package generic_func_pack;
	function bit is_pow2(int num);
		return num == (2 ** $clog2(num));
	endfunction : is_pow2
endpackage : generic_func_pack