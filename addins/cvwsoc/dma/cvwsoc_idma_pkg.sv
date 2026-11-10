package cvwsoc_idma_pkg;

  // CVWSoC iDMA register offsets relative to each frontend's configured base.
  localparam logic [15:0] IDMA_IRQ_STATUS_OFFSET = 16'h0100;
  localparam logic [15:0] IDMA_IRQ_ENABLE_OFFSET = 16'h0104;
  localparam logic [15:0] IDMA_AXIS_CYCLIC_CTRL_OFFSET = 16'h0110;

endpackage
