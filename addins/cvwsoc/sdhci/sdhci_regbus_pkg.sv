package sdhci_regbus_pkg;
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
