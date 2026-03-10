// package vga_regbus_pkg;
//   `include "register_interface/typedef.svh"

//   typedef logic [31:0] reg_addr_t;
//   typedef logic [31:0] reg_data_t;
//   typedef logic [3:0]  reg_strb_t;

//   `REG_BUS_TYPEDEF_REQ(reg_req_t, reg_addr_t, reg_data_t, reg_strb_t)
//   `REG_BUS_TYPEDEF_RSP(reg_rsp_t, reg_data_t)
// endpackage
package vga_regbus_pkg;
  typedef struct packed {
    logic        valid;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
  } reg_req_t;

  typedef struct packed {
    logic [31:0] rdata;
    logic        error;
    logic        ready;
  } reg_resp_t;
endpackage
