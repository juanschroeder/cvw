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
  input  logic [P.XLEN-1:0]    HWDATA,
  input  logic [P.XLEN/8-1:0]  HWSTRB,
  input  logic                 HWRITE,
  input  logic [1:0]           HTRANS,
  input  logic                 HREADY,

  output logic [P.XLEN-1:0]    HREADWb,
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
    if (!(P.XLEN == 32 || P.XLEN == 64)) $error("wb_ahb: only XLEN=32/64 supported.");
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
      if (P.XLEN == 32) begin
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
            lane_hi_q <= (P.XLEN == 64) ? HADDR[2] : 1'b0;

            if (HWRITE) st <= CAP_WDATA;   // wait for data phase
            else        st <= WB_WAIT;     // reads can go straight to WB
          end
        end

        CAP_WDATA: begin
          // latch data + strobes together in data phase (THIS IS THE REAL FIX)
          if (P.XLEN == 32) begin
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


// // wb_ahb.sv
// // Wally AHB-lite-peripheral-style (HWSTRB) -> Wishbone B4 (32-bit data) bridge wrapper
// // Fixes:
// //  - capture HWDATA/HWSTRB in AHB data phase for writes
// //  - force wb_sel on reads (HWSTRB often 0 on reads)
// //  - hold WB cycle stable until ack/err

// module wb_ahb import cvw::*; #(
//   parameter cvw_t P,
//   parameter int WB_DW = 32,
//   parameter int WB_AW = 30
// ) (
//   input  logic                 HCLK, HRESETn,

//   input  logic                 HSELWb,
//   input  logic [P.PA_BITS-1:0] HADDR,
//   input  logic [P.XLEN-1:0]    HWDATA,
//   input  logic [P.XLEN/8-1:0]  HWSTRB,
//   input  logic                 HWRITE,
//   input  logic [1:0]           HTRANS,
//   input  logic                 HREADY,

//   output logic [P.XLEN-1:0]    HREADWb,
//   output logic                 HRESPWb, HREADYWb,

//   output logic [WB_AW-1:0]     wb_adr_o,
//   output logic [WB_DW-1:0]     wb_dat_o,
//   input  logic [WB_DW-1:0]     wb_dat_i,
//   output logic [WB_DW/8-1:0]   wb_sel_o,
//   output logic                 wb_we_o,
//   output logic                 wb_cyc_o,
//   output logic                 wb_stb_o,
//   input  logic                 wb_ack_i,
//   input  logic                 wb_err_i
// );

//   initial begin
//     if (WB_DW != 32) $error("wb_ahb: WB_DW must be 32.");
//     if (!(P.XLEN == 32 || P.XLEN == 64)) $error("wb_ahb: only XLEN=32/64 supported.");
//   end

//   wire ahb_xfer = HSELWb && HREADY && HTRANS[1];
//   wire wb_done  = wb_ack_i | wb_err_i;

//   logic [P.PA_BITS-1:0] addr_q;
//   logic                 we_q;
//   logic                 lane_hi_q;
//   logic [31:0]          wdata_q;
//   logic [3:0]           sel_q;

//   typedef enum logic [1:0] {IDLE, CAP_WDATA, WB_WAIT} st_t;
//   st_t st;

//   // compute 32b write data from current HWDATA (used in CAP_WDATA)
//   logic [31:0] wdata32_now;
//   always_comb begin
//     if (P.XLEN == 32) begin
//       wdata32_now = HWDATA[31:0];
//     end else begin
//       wdata32_now = lane_hi_q ? HWDATA[63:32] : HWDATA[31:0];
//     end
//   end

//   // WB outputs
//   assign wb_adr_o = addr_q[WB_AW+1:2];
//   assign wb_dat_o = wdata_q;
//   assign wb_we_o  = we_q;
//   assign wb_cyc_o = (st == WB_WAIT);
//   assign wb_stb_o = (st == WB_WAIT);

//   // SEL: force valid on reads; use captured sel_q on writes
//   always_comb begin
//     if (!we_q) wb_sel_o = 4'b0001;
//     else       wb_sel_o = (sel_q == 4'h0) ? 4'hF : sel_q;
//   end

//   // AHB ready/resp
//   always_comb begin
//     unique case (st)
//       IDLE:      begin HREADYWb = 1'b1;    HRESPWb = 1'b0; end
//       CAP_WDATA: begin HREADYWb = 1'b0;    HRESPWb = 1'b0; end
//       default:   begin HREADYWb = wb_done; HRESPWb = wb_err_i; end
//     endcase
//   end

//   // Read data on completion
//   always_comb begin
//     HREADWb = '0;
//     if ((st == WB_WAIT) && wb_done && !we_q) begin
//       if (P.XLEN == 32) begin
//         HREADWb[31:0] = wb_dat_i[31:0];
//       end else begin
//         if (lane_hi_q) HREADWb[63:32] = wb_dat_i[31:0];
//         else           HREADWb[31:0]  = wb_dat_i[31:0];
//       end
//     end
//   end

//   // FSM
//   always_ff @(posedge HCLK or negedge HRESETn) begin
//     if (!HRESETn) begin
//       st        <= IDLE;
//       addr_q    <= '0;
//       we_q      <= 1'b0;
//       lane_hi_q <= 1'b0;
//       wdata_q   <= 32'h0;
//       sel_q     <= 4'h0;
//     end else begin
//       case (st)
//         IDLE: begin
//           if (ahb_xfer) begin
//             addr_q    <= HADDR;
//             we_q      <= HWRITE;
//             lane_hi_q <= (P.XLEN == 64) ? HADDR[2] : 1'b0;

//             if (HWRITE) begin
//               // CAPTURE STRB IN ADDRESS PHASE (this is the key fix)
//               if (P.XLEN == 32) sel_q <= HWSTRB[3:0];
//               else              sel_q <= HADDR[2] ? HWSTRB[7:4] : HWSTRB[3:0];

//               st <= CAP_WDATA;
//             end else begin
//               st <= WB_WAIT;
//             end
//           end
//         end

//         CAP_WDATA: begin
//           // capture write data in data phase
//           wdata_q <= wdata32_now;
//           st      <= WB_WAIT;
//         end

//         WB_WAIT: begin
//           if (wb_done) st <= IDLE;
//         end

//         default: st <= IDLE;
//       endcase
//     end
//   end

// endmodule


// // module wb_ahb import cvw::*; #(
// //   parameter cvw_t P,
// //   parameter int WB_DW = 32,
// //   parameter int WB_AW = 30   // word address bits: byte>>2
// // ) (
// //   input  logic                 HCLK, HRESETn,

// //   input  logic                 HSELWb,
// //   input  logic [P.PA_BITS-1:0] HADDR,
// //   input  logic [P.XLEN-1:0]    HWDATA,
// //   input  logic [P.XLEN/8-1:0]  HWSTRB,
// //   input  logic                 HWRITE,
// //   input  logic [1:0]           HTRANS,
// //   input  logic                 HREADY,

// //   output logic [P.XLEN-1:0]    HREADWb,
// //   output logic                 HRESPWb, HREADYWb,

// //   output logic [WB_AW-1:0]     wb_adr_o,   // word address
// //   output logic [WB_DW-1:0]     wb_dat_o,
// //   input  logic [WB_DW-1:0]     wb_dat_i,
// //   output logic [WB_DW/8-1:0]   wb_sel_o,
// //   output logic                 wb_we_o,
// //   output logic                 wb_cyc_o,
// //   output logic                 wb_stb_o,
// //   input  logic                 wb_ack_i,
// //   input  logic                 wb_err_i
// // );

// //   initial begin
// //     if (WB_DW != 32) $error("wb_ahb: WB_DW must be 32.");
// //     if (!(P.XLEN == 32 || P.XLEN == 64)) $error("wb_ahb: only XLEN=32/64 supported.");
// //   end

// //   // valid AHB transfer (selected + NONIDLE)
// //   wire ahb_xfer = HSELWb && HREADY && HTRANS[1];

// //   // hold request fields
// //   logic [P.PA_BITS-1:0] addr_q;
// //   logic                 we_q;
// //   logic                 lane_hi_q;      // for XLEN=64
// //   logic [31:0]          wdata_q;
// //   logic [3:0]           sel_q;

// //   // state
// //   typedef enum logic [1:0] {IDLE, CAP_WDATA, WB_WAIT} st_t;
// //   st_t st;

// //   wire wb_done = wb_ack_i | wb_err_i;

// //   // compute 32-bit lane from current bus (used during CAP_WDATA)
// //   wire lane_hi_now = (P.XLEN == 64) ? addr_q[2] : 1'b0;

// //   logic [31:0] wdata32_now;
// //   logic [3:0]  sel32_now;

// //   always_comb begin
// //     if (P.XLEN == 32) begin
// //       wdata32_now = HWDATA[31:0];
// //       sel32_now   = HWSTRB[3:0];
// //     end else begin
// //       wdata32_now = lane_hi_now ? HWDATA[63:32] : HWDATA[31:0];
// //       sel32_now   = lane_hi_now ? HWSTRB[7:4]   : HWSTRB[3:0];
// //     end
// //   end

// //   // Wishbone outputs
// //   assign wb_adr_o = addr_q[WB_AW+1:2];
// //   assign wb_dat_o = wdata_q;
// //   assign wb_we_o  = we_q;
// //   assign wb_cyc_o = (st == WB_WAIT);
// //   assign wb_stb_o = (st == WB_WAIT);

// //   // IMPORTANT: wb_sel_o
// //   // - reads: force a sane select (don’t use HWSTRB which is often 0)
// //   // - writes: use captured sel_q, but never let it be 0
// //   always_comb begin
// //     if (!we_q) wb_sel_o = 4'b0001;                 // read
// //     else       wb_sel_o = (sel_q == 4'h0) ? 4'hF : sel_q; // write
// //   end

// //   // AHB ready/resp
// //   // - IDLE: ready=1
// //   // - CAP_WDATA: stall (need one data-phase cycle to capture HWDATA/HWSTRB)
// //   // - WB_WAIT: stall until wb_done, then complete transfer
// //   always_comb begin
// //     unique case (st)
// //       IDLE:      begin HREADYWb = 1'b1;    HRESPWb = 1'b0; end
// //       CAP_WDATA: begin HREADYWb = 1'b0;    HRESPWb = 1'b0; end
// //       default:   begin HREADYWb = wb_done; HRESPWb = wb_err_i; end
// //     endcase
// //   end

// //   // Read data returned on completion cycle
// //   always_comb begin
// //     HREADWb = '0;
// //     if ((st == WB_WAIT) && wb_done && !we_q) begin
// //       if (P.XLEN == 32) begin
// //         HREADWb[31:0] = wb_dat_i[31:0];
// //       end else begin
// //         if (lane_hi_q) HREADWb[63:32] = wb_dat_i[31:0];
// //         else           HREADWb[31:0]  = wb_dat_i[31:0];
// //       end
// //     end
// //   end

// //   // FSM
// //   always_ff @(posedge HCLK or negedge HRESETn) begin
// //     if (!HRESETn) begin
// //       st        <= IDLE;
// //       addr_q    <= '0;
// //       we_q      <= 1'b0;
// //       lane_hi_q <= 1'b0;
// //       wdata_q   <= 32'h0;
// //       sel_q     <= 4'h0;
// //     end else begin
// //       case (st)
// //         IDLE: begin
// //           if (ahb_xfer) begin
// //             addr_q    <= HADDR;
// //             we_q      <= HWRITE;
// //             lane_hi_q <= (P.XLEN == 64) ? HADDR[2] : 1'b0;

// //             if (HWRITE) begin
// //               // write: capture data next cycle (AHB data phase)
// //               st <= CAP_WDATA;
// //             end else begin
// //               // read: can start WB immediately
// //               st <= WB_WAIT;
// //             end
// //           end
// //         end

// //         CAP_WDATA: begin
// //           // now we are in the data phase for this write (master holds data stable until ready)
// //           wdata_q <= wdata32_now;
// //           sel_q   <= sel32_now;
// //           st      <= WB_WAIT;
// //         end

// //         WB_WAIT: begin
// //           if (wb_done) begin
// //             st <= IDLE;
// //           end
// //         end

// //         default: st <= IDLE;
// //       endcase
// //     end
// //   end

// // endmodule



// // // wb_ahb.sv
// // // Wally AHB-lite-peripheral-style (HWSTRB) -> Wishbone B4 (32-bit data) bridge wrapper
// // // - Single outstanding transfer (stall AHB until WB ACK/ERR)
// // // - Wishbone adr_o is WORD address (byte_addr >> 2), LiteX-style
// // // - For RV64, uses HADDR[2] to select low/high 32-bit lane; region should DISALLOW 64-bit accesses

// // module wb_ahb import cvw::*; #(
// //   parameter cvw_t P,
// //   parameter int WB_DW = 32,
// //   parameter int WB_AW = 30   // word address bits: 4GB byte space => 30 bits words
// // ) (
// //   input  logic                 HCLK,
// //   input  logic                 HRESETn,

// //   // AHB-lite-peripheral-style inputs from uncore
// //   input  logic                 HSELWb,
// //   input  logic [P.PA_BITS-1:0] HADDR,
// //   input  logic [P.XLEN-1:0]    HWDATA,
// //   input  logic [P.XLEN/8-1:0]  HWSTRB,
// //   input  logic                 HWRITE,
// //   input  logic [1:0]           HTRANS,
// //   input  logic                 HREADY,

// //   // AHB response back to uncore
// //   output logic [P.XLEN-1:0]    HREADWb,
// //   output logic                 HRESPWb,
// //   output logic                 HREADYWb,

// //   // Wishbone B4 master out to the "WB island"
// //   output logic [WB_AW-1:0]     wb_adr_o,   // word address
// //   output logic [WB_DW-1:0]     wb_dat_o,
// //   input  logic [WB_DW-1:0]     wb_dat_i,
// //   output logic [WB_DW/8-1:0]   wb_sel_o,
// //   output logic                 wb_we_o,
// //   output logic                 wb_cyc_o,
// //   output logic                 wb_stb_o,
// //   input  logic                 wb_ack_i,
// //   input  logic                 wb_err_i
// // );

// //   localparam int STRB_W = P.XLEN/8;

// //   // Only intended for WB_DW=32 for LiteX-ish peripherals
// //   initial begin
// //     if (WB_DW != 32) $error("wb_ahb: WB_DW must be 32 for this wrapper.");
// //     if (!(P.XLEN == 32 || P.XLEN == 64)) $error("wb_ahb: only XLEN=32/64 supported.");
// //   end

// //   // Valid AHB transfer when selected and active transfer type
// //   wire ahb_xfer = HSELWb && HREADY && HTRANS[1];

// //   // Lane select for RV64 (low/high 32b word inside 64b)
// //   wire lane_hi = (P.XLEN == 64) ? HADDR[2] : 1'b0;

// //   // Derive 32-bit write data and 4-bit sel from XLEN bus
// //   logic [31:0] wdata32;
// //   logic [3:0]  sel32;

// //   always_comb begin
// //     if (P.XLEN == 32) begin
// //       wdata32 = HWDATA[31:0];
// //       sel32   = HWSTRB[3:0];
// //     end else begin // XLEN==64
// //       wdata32 = lane_hi ? HWDATA[63:32] : HWDATA[31:0];
// //       sel32   = lane_hi ? HWSTRB[7:4]   : HWSTRB[3:0];
// //     end
// //   end

// //   // One-deep request holding regs
// //   typedef enum logic [0:0] {IDLE, BUSY} st_t;
// //   st_t                    st;

// //   logic [P.PA_BITS-1:0]   addr_q;
// //   logic                   we_q;
// //   logic [31:0]            wdata_q;
// //   logic [3:0]             sel_q;

// //   wire wb_done = wb_ack_i | wb_err_i;

// //   // Drive WB outputs from holding regs
// //   always_comb begin
// //     wb_adr_o = addr_q[WB_AW+1:2];  // word address (byte >> 2)
// //     wb_dat_o = wdata_q;
// //     wb_sel_o = sel_q;
// //     wb_we_o  = we_q;
// //     wb_cyc_o = (st == BUSY);
// //     wb_stb_o = (st == BUSY);
// //   end

  
// //   // AHB ready/resp:
// //   // - IDLE: ready=1
// //   // - BUSY: ready goes high only on wb_done (final cycle)
// //   always_comb begin
// //     HREADYWb = (st == IDLE) ? 1'b1 : wb_done;
// //     HRESPWb  = (st == BUSY) ? wb_err_i : 1'b0;
// //   end

// //   // Read data: must be valid in the same cycle we raise HREADYWb (i.e. wb_done cycle).
// //   // So we forward wb_dat_i combinationally on completion.
// //   logic [31:0] rdata32_fwd;
// //   always_comb begin
// //     rdata32_fwd = wb_dat_i[31:0];
// //   end

// //   always_comb begin
// //     // Default 0-fill
// //     HREADWb = '0;
// //     if (P.XLEN == 32) begin
// //       if (st == BUSY && wb_done && !we_q) HREADWb[31:0] = rdata32_fwd;
// //     end else begin // XLEN==64
// //       if (st == BUSY && wb_done && !we_q) begin
// //         if (addr_q[2]) HREADWb[63:32] = rdata32_fwd;
// //         else           HREADWb[31:0]  = rdata32_fwd;
// //       end
// //     end
// //   end

// //   // FSM: accept transfer -> start WB -> stall AHB until ACK/ERR
// //   always_ff @(posedge HCLK or negedge HRESETn) begin
// //     if (!HRESETn) begin
// //       st     <= IDLE;
// //       addr_q <= '0;
// //       we_q   <= 1'b0;
// //       wdata_q<= '0;
// //       sel_q  <= '0;
// //     end else begin
// //       case (st)
// //         IDLE: begin
// //           if (ahb_xfer) begin
// //             st     <= BUSY;
// //             addr_q <= HADDR;
// //             we_q   <= HWRITE;
// //             wdata_q<= wdata32;
// //             //sel_q  <= sel32;
// //             sel_q <= HWRITE ? sel32 : 4'hF;
// //           end
// //         end
// //         BUSY: begin
// //           if (wb_done) begin
// //             st <= IDLE;
// //           end
// //         end
// //       endcase
// //     end
// //   end

// // endmodule
