module wb_island #(
  parameter int AW = 30
) (
  input  logic          clk,
  input  logic          rst,     // active high

  // master in
  input  logic [AW-1:0] m_adr_i, // absolute word address
  input  logic [31:0]   m_dat_i,
  output logic [31:0]   m_dat_o,
  input  logic [3:0]    m_sel_i,
  input  logic          m_we_i,
  input  logic          m_cyc_i,
  input  logic          m_stb_i,
  output logic          m_ack_o,
  output logic          m_err_o,

  // external pins owned by island devices
  // UART
  input  logic          uart_rx_i,
  output logic          uart_tx_o,
  output logic          uart_irq_o
  // Ethernet
  ,
  input  logic        rmii_ref_clk,
  input  logic        rmii_crs_dv,
  input  logic [1:0]  rmii_rx_data,
  output logic [1:0]  rmii_tx_data,
  output logic        rmii_tx_en,
  output logic        rmii_mdc,
  inout  wire         rmii_mdio,
  output logic        rmii_rst_n,
  output logic        eth_irq  
);

  // Address map (BYTE)
  localparam logic [31:0] UART_BASE_B = 32'h1100_4000;
  localparam logic [31:0] UART_SIZE_B = 32'h0000_1000;

  localparam logic [31:0] STUB_BASE_B = 32'h1100_5000;
  localparam logic [31:0] STUB_SIZE_B = 32'h0000_1000;

  localparam logic [31:0] ETH_BASE_B     = 32'h1100_0000;
  localparam logic [31:0] ETH_SIZE_B     = 32'h0000_4000;
  localparam logic [31:0] ETH_CSR_OFF_B  = 32'h0000_2000;

  // Convert to WORD space
  localparam logic [AW-1:0] UART_BASE_W = UART_BASE_B[AW+1:2];
  localparam logic [AW-1:0] UART_SIZE_W = (UART_SIZE_B >> 2);

  localparam logic [AW-1:0] STUB_BASE_W = STUB_BASE_B[AW+1:2];
  localparam logic [AW-1:0] STUB_SIZE_W = (STUB_SIZE_B >> 2);

  localparam logic [AW-1:0] ETH_BASE_W     = ETH_BASE_B[AW+1:2];
  localparam logic [AW-1:0] ETH_SIZE_W     = (ETH_SIZE_B >> 2);
  // CPU address classification must be based on ORIGINAL address (m_adr_i),
  // not the translated CSR-relative address.
  localparam logic [AW-1:0] ETH_CSR_BASE_W = ETH_BASE_W + (ETH_CSR_OFF_B >> 2);  

  function automatic logic in_range(
    input logic [AW-1:0] a,
    input logic [AW-1:0] base,
    input logic [AW-1:0] size
  );
    return (a >= base) && (a < (base + size));
  endfunction

  wire hit_uart = in_range(m_adr_i, UART_BASE_W, UART_SIZE_W);
  wire hit_stub = in_range(m_adr_i, STUB_BASE_W, STUB_SIZE_W);
  wire hit_eth = in_range(m_adr_i, ETH_BASE_W, ETH_SIZE_W);

  // Gate cycles
  wire uart_cyc = m_cyc_i & hit_uart;
  wire uart_stb = m_stb_i & hit_uart;

  wire stub_cyc = m_cyc_i & hit_stub;
  wire stub_stb = m_stb_i & hit_stub;

  wire eth_cyc = m_cyc_i & hit_eth;
  wire eth_stb = m_stb_i & hit_eth;

  // UART
  logic [31:0] uart_rdata;
  logic        uart_ack, uart_err;

  wb_uart16550 #(.AW(AW), .UART_BASE_B(UART_BASE_B)) u_uart (
    .clk(clk), .rst(rst),
    .adr_i(m_adr_i), .dat_i(m_dat_i), .dat_o(uart_rdata),
    .sel_i(m_sel_i), .we_i(m_we_i), .cyc_i(uart_cyc), .stb_i(uart_stb),
    .ack_o(uart_ack), .err_o(uart_err),
    .irq_o(uart_irq_o), .rx_i(uart_rx_i), .tx_o(uart_tx_o)
  );

  logic [31:0] eth_dat_r;
  logic        eth_ack, eth_err;
  //logic [29:0] eth_rel_addr;
  //assign eth_rel_addr = m_adr_i - ETH_BASE_B;

  //localparam logic [AW-1:0] ETH_BUF_END_W = ETH_BASE_W + (ETH_BUF_SIZE_B >> 2);
  //localparam logic [AW-1:0] ETH_CSR_BASE_W= ETH_BASE_W + (ETH_CSR_OFF_B  >> 2);
  logic [AW-1:0] eth_adr_w;
  always_comb begin
    if (m_adr_i >= ETH_CSR_BASE_W)
      eth_adr_w = m_adr_i - ETH_CSR_BASE_W; // -> 0x0000_xxxx (CSR space)
    else
      eth_adr_w = m_adr_i;                  // -> 0x1100_xxxx (buffer space)
  end


  function automatic [31:0] bswap32(input [31:0] x);
    bswap32 = {x[7:0], x[15:8], x[23:16], x[31:24]};
  endfunction
  wire eth_is_buf = hit_eth && (m_adr_i < ETH_CSR_BASE_W);
  // swap data + reverse byte enables only for buffer window
  wire [31:0] eth_dat_w = eth_is_buf ? bswap32(m_dat_i) : m_dat_i;
  wire [3:0]  eth_sel_w = eth_is_buf ? {m_sel_i[0], m_sel_i[1], m_sel_i[2], m_sel_i[3]} : m_sel_i;


  liteEthTop u_liteeth (
    .interrupt(eth_irq),

    .rmii_clocks_ref_clk(rmii_ref_clk),
    .rmii_crs_dv        (rmii_crs_dv),
    .rmii_mdc           (rmii_mdc),
    .rmii_mdio          (rmii_mdio),
    .rmii_rst_n         (rmii_rst_n),
    .rmii_rx_data       (rmii_rx_data),
    .rmii_tx_data       (rmii_tx_data),
    .rmii_tx_en         (rmii_tx_en),

    .sys_clock          (clk),
    .sys_reset          (rst),

    .wishbone_ack       (eth_ack),
    //.wishbone_adr       (m_adr_i[29:0]),   // AW should be 30; slice is fine
    .wishbone_adr (eth_adr_w[29:0]),
    .wishbone_bte       (2'b00),           // no bursts
    .wishbone_cti       (3'b000),          // classic
    .wishbone_cyc       (eth_cyc),
    .wishbone_dat_r     (eth_dat_r),
    .wishbone_err       (eth_err),
    // .wishbone_dat_w     (m_dat_i),
    // .wishbone_sel       (m_sel_i),
    .wishbone_dat_w     (eth_dat_w),
    .wishbone_sel       (eth_sel_w),
    .wishbone_stb       (eth_stb),
    .wishbone_we        (m_we_i)
  );

  // return path swap for buffer reads
  wire [31:0] eth_dat_r_cpu = eth_is_buf ? bswap32(eth_dat_r) : eth_dat_r;

    // Stub (unchanged module of yours)
  logic [31:0] stub_rdata;
  logic        stub_ack, stub_err;

  wb_stub #(.AW(AW)) u_stub (
    .clk(clk), .rst(rst),
    .adr_i(m_adr_i), .dat_i(m_dat_i), .dat_o(stub_rdata),
    .sel_i(m_sel_i), .we_i(m_we_i), .cyc_i(stub_cyc), .stb_i(stub_stb),
    .ack_o(stub_ack), .err_o(stub_err)
  );

  // Return mux + unmapped -> immediate error (no hang)
  always_comb begin
    m_dat_o = 32'h0;
    m_ack_o = 1'b0;
    m_err_o = 1'b0;

    if (hit_eth) begin
      //m_dat_o = eth_dat_r;
      m_dat_o = eth_dat_r_cpu;
      m_ack_o = eth_ack;
      m_err_o = eth_err;
    end else if (hit_uart) begin
      m_dat_o = uart_rdata; m_ack_o = uart_ack; m_err_o = uart_err;
    end else if (hit_stub) begin
      m_dat_o = stub_rdata; m_ack_o = stub_ack; m_err_o = stub_err;
    end else if (m_cyc_i & m_stb_i) begin
      m_dat_o = 32'hBAD0_BAD0;
      m_ack_o = 1'b1;
      m_err_o = 1'b1;
    end
  end

endmodule
