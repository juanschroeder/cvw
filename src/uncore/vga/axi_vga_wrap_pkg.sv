// axi_vga_wrap_pkg.sv
package axi_vga_wrap_pkg;

  // Must be compiled after axi_pkg.sv is available in the library
  import axi_pkg::*;

  `include "axi/typedef.svh"

  localparam int unsigned AXI_ADDR_W = 32;
  localparam int unsigned AXI_DATA_W = 64;
  localparam int unsigned AXI_ID_W   = 4;
  localparam int unsigned AXI_USER_W = 1;

  typedef logic [AXI_ADDR_W-1:0] axi_addr_t;
  typedef logic [AXI_DATA_W-1:0] axi_data_t;
  typedef logic [AXI_DATA_W/8-1:0] axi_strb_t;
  typedef logic [AXI_ID_W-1:0]   axi_id_t;
  typedef logic [AXI_USER_W-1:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T (axi_w_t,  axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T (axi_b_t,  axi_id_t,   axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T (axi_r_t,  axi_data_t, axi_id_t, axi_user_t)

  `AXI_TYPEDEF_REQ_T (axi_req_t,  axi_aw_t, axi_w_t, axi_ar_t)
  `AXI_TYPEDEF_RESP_T(axi_resp_t, axi_b_t,  axi_r_t)

endpackage
