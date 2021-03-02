module prim_fifo_sync (
	clk_i,
	rst_ni,
	clr_i,
	wvalid,
	wready,
	wdata,
	rvalid,
	rready,
	rdata,
	depth,
	_fifo_wptr,
	_fifo_rptr,
	_storage
);
	parameter [31:0] Width = 16;
	parameter [0:0] Pass = 1'b1;
	parameter [31:0] Depth = 4;
	parameter [0:0] OutputZeroIfEmpty = 1'b1;
	localparam [31:0] DepthWNorm = $clog2(Depth + 1);
	localparam [31:0] DepthW = (DepthWNorm == 0 ? 1 : DepthWNorm);
	localparam [31:0] PTRV_W = $clog2(Depth) + ~|$clog2(Depth);
	localparam [31:0] PTR_WIDTH = PTRV_W + 1;
	input clk_i;
	input rst_ni;
	input clr_i;
	input wvalid;
	output wready;
	input [Width - 1:0] wdata;
	output rvalid;
	input rready;
	output [Width - 1:0] rdata;
	output [DepthW - 1:0] depth;
	output [PTR_WIDTH - 1:0] _fifo_wptr;
	output [PTR_WIDTH - 1:0] _fifo_rptr;
	output [(0 >= (Depth - 1) ? ((2 - Depth) * Width) + (((Depth - 1) * Width) - 1) : (Depth * Width) - 1):(0 >= (Depth - 1) ? (Depth - 1) * Width : 0)] _storage;
	generate
		if (Depth == 0) begin : gen_passthru_fifo
			assign depth = 1'b0;
			assign rvalid = wvalid;
			assign rdata = wdata;
			assign wready = rready;
			wire unused_clr;
			assign unused_clr = clr_i;
		end
		else begin : gen_normal_fifo
			reg [PTR_WIDTH - 1:0] fifo_wptr;
			reg [PTR_WIDTH - 1:0] fifo_rptr;
			wire fifo_incr_wptr;
			wire fifo_incr_rptr;
			wire fifo_empty;
			wire full;
			wire empty;
			wire wptr_msb;
			wire rptr_msb;
			wire [PTRV_W - 1:0] wptr_value;
			wire [PTRV_W - 1:0] rptr_value;
			assign wptr_msb = fifo_wptr[PTR_WIDTH - 1];
			assign rptr_msb = fifo_rptr[PTR_WIDTH - 1];
			assign wptr_value = fifo_wptr[0+:PTRV_W];
			assign rptr_value = fifo_rptr[0+:PTRV_W];
			function automatic [DepthW - 1:0] sv2v_cast_703F8;
				input reg [DepthW - 1:0] inp;
				sv2v_cast_703F8 = inp;
			endfunction
			assign depth = (full ? sv2v_cast_703F8(Depth) : (wptr_msb == rptr_msb ? sv2v_cast_703F8(wptr_value) - sv2v_cast_703F8(rptr_value) : (sv2v_cast_703F8(Depth) - sv2v_cast_703F8(rptr_value)) + sv2v_cast_703F8(wptr_value)));
			assign fifo_incr_wptr = wvalid & wready;
			assign fifo_incr_rptr = rvalid & rready;
			assign wready = ~full;
			assign rvalid = ~empty;
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni)
					fifo_wptr <= {PTR_WIDTH {1'b0}};
				else if (clr_i)
					fifo_wptr <= {PTR_WIDTH {1'b0}};
				else if (fifo_incr_wptr)
					if (fifo_wptr[PTR_WIDTH - 2:0] == (Depth - 1))
						fifo_wptr <= {~fifo_wptr[PTR_WIDTH - 1], {PTR_WIDTH - 1 {1'b0}}};
					else
						fifo_wptr <= fifo_wptr + {{PTR_WIDTH - 1 {1'b0}}, 1'b1};
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni)
					fifo_rptr <= {PTR_WIDTH {1'b0}};
				else if (clr_i)
					fifo_rptr <= {PTR_WIDTH {1'b0}};
				else if (fifo_incr_rptr)
					if (fifo_rptr[PTR_WIDTH - 2:0] == (Depth - 1))
						fifo_rptr <= {~fifo_rptr[PTR_WIDTH - 1], {PTR_WIDTH - 1 {1'b0}}};
					else
						fifo_rptr <= fifo_rptr + {{PTR_WIDTH - 1 {1'b0}}, 1'b1};
			assign full = fifo_wptr == (fifo_rptr ^ {1'b1, {PTR_WIDTH - 1 {1'b0}}});
			assign fifo_empty = fifo_wptr == fifo_rptr;
			reg [(0 >= (Depth - 1) ? ((2 - Depth) * Width) + (((Depth - 1) * Width) - 1) : (Depth * Width) - 1):(0 >= (Depth - 1) ? (Depth - 1) * Width : 0)] storage;
			wire [Width - 1:0] storage_rdata;
			if (Depth == 1) begin : gen_depth_eq1
				assign storage_rdata = storage[(0 >= (Depth - 1) ? 0 : Depth - 1) * Width+:Width];
				always @(posedge clk_i)
					if (fifo_incr_wptr)
						storage[(0 >= (Depth - 1) ? 0 : Depth - 1) * Width+:Width] <= wdata;
			end
			else begin : gen_depth_gt1
				assign storage_rdata = storage[(0 >= (Depth - 1) ? fifo_rptr[PTR_WIDTH - 2:0] : (Depth - 1) - fifo_rptr[PTR_WIDTH - 2:0]) * Width+:Width];
				always @(posedge clk_i)
					if (fifo_incr_wptr)
						storage[(0 >= (Depth - 1) ? fifo_wptr[PTR_WIDTH - 2:0] : (Depth - 1) - fifo_wptr[PTR_WIDTH - 2:0]) * Width+:Width] <= wdata;
			end
			wire [Width - 1:0] rdata_int;
			if (Pass == 1'b1) begin : gen_pass
				assign rdata_int = (fifo_empty && wvalid ? wdata : storage_rdata);
				assign empty = fifo_empty & ~wvalid;
			end
			else begin : gen_nopass
				assign rdata_int = storage_rdata;
				assign empty = fifo_empty;
			end
			if (OutputZeroIfEmpty == 1'b1) begin : gen_output_zero
				assign rdata = (empty ? 'b0 : rdata_int);
			end
			else begin : gen_no_output_zero
				assign rdata = rdata_int;
			end
			assign _fifo_wptr = fifo_wptr;
			assign _fifo_rptr = fifo_rptr;
			assign _storage = storage;
		end
	endgenerate
endmodule
