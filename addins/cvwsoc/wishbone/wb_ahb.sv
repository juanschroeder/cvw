// wb_ahb.sv
// Wally AHB-lite-peripheral-style (HWSTRB) -> Wishbone B4 (32-bit data) bridge wrapper
// Fixes:
//  - capture HWDATA + HWSTRB together in AHB data phase for writes
//  - drive wb_sel_o sane on reads (4'hF)
//  - hold WB cycle stable until ack/err

module wb_ahb import cvw::*; #(
  parameter cvw_t P,
  parameter int WB_DW = 32,
  parameter int WB_AW = 30
) (
  input  logic                 HCLK, HRESETn,

  input  logic                 HSELWb,
  input  logic [P.PA_BITS-1:0] HADDR,
  input  logic [P.AHBW-1:0]    HWDATA,
  input  logic [P.AHBW/8-1:0]  HWSTRB,
  input  logic                 HWRITE,
  input  logic [1:0]           HTRANS,
  input  logic                 HREADY,

  output logic [P.AHBW-1:0]    HREADWb,
  output logic                 HRESPWb, HREADYWb,

  output logic [WB_AW-1:0]     wb_adr_o,
  output logic [WB_DW-1:0]     wb_dat_o,
  input  logic [WB_DW-1:0]     wb_dat_i,
  output logic [WB_DW/8-1:0]   wb_sel_o,
  output logic                 wb_we_o,
  output logic                 wb_cyc_o,
  output logic                 wb_stb_o,
  input  logic                 wb_ack_i,
  input  logic                 wb_err_i
);

  initial begin
    if (WB_DW != 32) $error("wb_ahb: WB_DW must be 32.");
    if (!(P.AHBW == 32 || P.AHBW == 64)) $error("wb_ahb: only AHBW=32/64 supported.");
  end

  // Address-phase “accept new transfer”
  wire ahb_xfer = HSELWb && HREADY && HTRANS[1];
  wire wb_done  = wb_ack_i | wb_err_i;

  logic [P.PA_BITS-1:0] addr_q;
  logic                 we_q;
  logic                 lane_hi_q;     // for XLEN=64: selects upper/lower 32-bit lane
  logic [31:0]          wdata_q;
  logic [3:0]           sel_q;

  typedef enum logic [1:0] {IDLE, CAP_WDATA, WB_WAIT} st_t;
  st_t st;

  // Wishbone outputs
  assign wb_adr_o = addr_q[WB_AW+1:2];
  assign wb_dat_o = wdata_q;
  assign wb_we_o  = we_q;
  assign wb_cyc_o = (st == WB_WAIT);
  assign wb_stb_o = (st == WB_WAIT);

  // wb_sel_o: for reads, just assert all lanes
  always_comb begin
    if (!we_q) wb_sel_o = 4'hF;
    else       wb_sel_o = (sel_q == 4'h0) ? 4'hF : sel_q;
  end

  // AHB ready/resp
  always_comb begin
    unique case (st)
      IDLE:      begin HREADYWb = 1'b1;    HRESPWb = 1'b0; end
      CAP_WDATA: begin HREADYWb = 1'b0;    HRESPWb = 1'b0; end
      default:   begin HREADYWb = wb_done; HRESPWb = wb_err_i; end
    endcase
  end

  // Read data when WB completes
  always_comb begin
    HREADWb = '0;
    if ((st == WB_WAIT) && wb_done && !we_q) begin
        if (P.AHBW == 32) begin
        HREADWb[31:0] = wb_dat_i[31:0];
      end else begin
        if (lane_hi_q) HREADWb[63:32] = wb_dat_i[31:0];
        else           HREADWb[31:0]  = wb_dat_i[31:0];
      end
    end
  end

  // FSM
  always_ff @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
      st        <= IDLE;
      addr_q    <= '0;
      we_q      <= 1'b0;
      lane_hi_q <= 1'b0;
      wdata_q   <= 32'h0;
      sel_q     <= 4'h0;
    end else begin
      case (st)
        IDLE: begin
          if (ahb_xfer) begin
            // latch address/control in address phase
            addr_q    <= HADDR;
            we_q      <= HWRITE;
            lane_hi_q <= (P.AHBW == 64) ? HADDR[2] : 1'b0;

            if (HWRITE) st <= CAP_WDATA;   // wait for data phase
            else        st <= WB_WAIT;     // reads can go straight to WB
          end
        end

        CAP_WDATA: begin
          // latch data + strobes together in data phase (THIS IS THE REAL FIX)
          if (P.AHBW == 32) begin
            wdata_q <= HWDATA[31:0];
            sel_q   <= HWSTRB[3:0];
          end else begin
            wdata_q <= lane_hi_q ? HWDATA[63:32] : HWDATA[31:0];
            sel_q   <= lane_hi_q ? HWSTRB[7:4]   : HWSTRB[3:0];
          end
          st <= WB_WAIT;
        end

        WB_WAIT: begin
          if (wb_done) st <= IDLE;
        end

        default: st <= IDLE;
      endcase
    end
  end

endmodule
