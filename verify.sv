module verify (
  input clk,
  input rst,
  input clr,
  input wvalid,
  input [Width-1:0] wdata,
  input rready
);

  parameter Width = 32;
  parameter Depth = 8; // must be >0
  parameter WithOutputPatch = 1; // Change to zero to make verification fail

  localparam DepthW = $clog2(Depth+1);
  localparam [31:0] PTRV_W = $clog2(Depth) + ~|$clog2(Depth);
  localparam [31:0] PTR_WIDTH = PTRV_W + 1;

  wire wready_impl, wready_spec;
  wire rvalid_impl, rvalid_spec;
  wire [Width-1:0] rdata_impl, rdata_spec;
  wire [DepthW-1:0] depth_impl, depth_spec;
  wire [PTR_WIDTH-1:0] fifo_wptr_impl, fifo_wptr_spec;
  wire [PTR_WIDTH-1:0] fifo_rptr_impl, fifo_rptr_spec;
  wire [Width*Depth-1:0] storage_impl, storage_spec;

  prim_fifo_sync #(
    .Width(Width),
    .Depth(Depth),
    .OutputZeroIfEmpty(WithOutputPatch)
  ) impl (
    .clk_i(clk),
    .rst_ni(rst),
    .clr_i(clr),
    .wvalid(wvalid),
    .wready(wready_impl),
    .wdata(wdata),
    .rvalid(rvalid_impl),
    .rready(rready),
    .rdata(rdata_impl),
    .depth(depth_impl),

    ._fifo_wptr(fifo_wptr_impl),
    ._fifo_rptr(fifo_rptr_impl),
    ._storage(storage_impl)
  );

  prim_fifo_sync #(
    .Width(Width),
    .Depth(Depth)
  ) spec (
    .clk_i(clk),
    .rst_ni(rst),
    .clr_i(clr),
    .wvalid(wvalid),
    .wready(wready_spec),
    .wdata(wdata),
    .rvalid(rvalid_spec),
    .rready(rready),
    .rdata(rdata_spec),
    .depth(depth_spec),

    ._fifo_wptr(fifo_wptr_spec),
    ._fifo_rptr(fifo_rptr_spec),
    ._storage(storage_spec)
  );
  // Assume spec is deterministically reset
  initial assume(storage_spec == {(Width*Depth)'b0});

  // Assume first cycle is reset
  initial assume(rst == 1'b0);

  function automatic [Width*Depth-1:0] get_live_storage(input [Width*Depth-1:0] storage, input [PTR_WIDTH-1:0] rptr, input [PTR_WIDTH-1:0] wptr);
    begin
      integer i;
      reg [Width*Depth-1:0] live_storage;
      if (rptr[PTR_WIDTH-1] == wptr[PTR_WIDTH-1]) begin
        // rptr and wptr have same msb
        for (i = 0; i < Depth; i = i + 1) begin
          if (rptr[PTR_WIDTH-2:0] <= i && i < wptr[PTR_WIDTH-2:0]) begin
            live_storage[((Depth-1)-i)*Width+:Width] = storage[((Depth-1)-i)*Width+:Width];
          end else begin
            live_storage[((Depth-1)-i)*Width+:Width] = {(Width)'b0};
          end
        end
      end else begin
        // rptr and wptr have different msb
        for (i = 0; i < Depth; i = i + 1) begin
          if ((rptr[PTR_WIDTH-2:0] <= i && i < Depth) ||
              (0 <= i && i < wptr[PTR_WIDTH-2:0])) begin
            live_storage[((Depth-1)-i)*Width+:Width] = storage[((Depth-1)-i)*Width+:Width];
          end else begin
            live_storage[((Depth-1)-i)*Width+:Width] = {(Width)'b0};
          end
        end
      end
      get_live_storage = live_storage;
    end
  endfunction

  wire [Width*Depth-1:0] live_storage_impl, live_storage_spec;
  assign live_storage_impl = get_live_storage(storage_impl, fifo_rptr_impl, fifo_wptr_impl);
  assign live_storage_spec = get_live_storage(storage_spec, fifo_rptr_spec, fifo_wptr_spec);

  // Assert outputs and all state besides storage is equal
  assert property (wready_impl == wready_spec &&
                   rvalid_impl == rvalid_spec &&
                   rdata_impl == rdata_spec &&
                   depth_impl == depth_spec &&
                   fifo_wptr_impl == fifo_wptr_spec &&
                   fifo_rptr_impl == fifo_rptr_spec);
  // Assert live storage is equal
  assert property(live_storage_impl == live_storage_spec);

  // Restrictions on pointer values
  assert property ((fifo_rptr_impl[PTR_WIDTH-1] == fifo_wptr_impl[PTR_WIDTH-1] && fifo_rptr_impl[PTR_WIDTH-2:0] <= fifo_wptr_impl[PTR_WIDTH-2:0]) ||
                   (fifo_rptr_impl[PTR_WIDTH-1] != fifo_wptr_impl[PTR_WIDTH-1] && fifo_rptr_impl[PTR_WIDTH-2:0] >= fifo_wptr_impl[PTR_WIDTH-2:0]));
  assert property ((fifo_rptr_spec[PTR_WIDTH-1] == fifo_wptr_spec[PTR_WIDTH-1] && fifo_rptr_spec[PTR_WIDTH-2:0] <= fifo_wptr_spec[PTR_WIDTH-2:0]) ||
                   (fifo_rptr_spec[PTR_WIDTH-1] != fifo_wptr_spec[PTR_WIDTH-1] && fifo_rptr_spec[PTR_WIDTH-2:0] >= fifo_wptr_spec[PTR_WIDTH-2:0]));
  assert property(fifo_wptr_impl[PTR_WIDTH-2:0] < Depth);
  assert property(fifo_rptr_impl[PTR_WIDTH-2:0] < Depth);
  assert property(fifo_wptr_spec[PTR_WIDTH-2:0] < Depth);
  assert property(fifo_rptr_spec[PTR_WIDTH-2:0] < Depth);

endmodule
