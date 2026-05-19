///////////////////////////////////////////
// rom1p1r_xc7
//
// OpenXC7/Yosys-slang replacement for Wally's rom1p1r preload path.
// yosys-slang currently rejects $readmemh, so the Makefile generates
// bootrom_case_xc7.svh from fpga/src/boot.mem during preprocessing.
///////////////////////////////////////////

module rom1p1r #(parameter ADDR_WIDTH = 8, DATA_WIDTH = 32, PRELOAD_ENABLED = 0, PRELOAD_START = 0)
  (input  logic                  clk,
   input  logic                  ce,
   input  logic [ADDR_WIDTH-1:0] addr,
   output logic [DATA_WIDTH-1:0] dout
);

  if (PRELOAD_ENABLED && DATA_WIDTH == 64) begin : bootrom
    always_ff @(posedge clk)
      if (ce) begin
        unique case (addr)
          `include "bootrom_case_xc7.svh"
          default: dout <= '0;
        endcase
      end
  end else begin : generic_rom
    bit [DATA_WIDTH-1:0] ROM [(2**ADDR_WIDTH)-1:0];

    always_ff @(posedge clk)
      if (ce) dout <= ROM[addr];
  end

endmodule
