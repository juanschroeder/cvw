`timescale 1ns/1ps

import cvw::*;
import cvwsoc_pkg::*;

// External devices shared by simulation and co-simulation testbenches.
// Connect these ports to the corresponding cvwsoc_axi board pins. Compile
// this module and its model dependencies only in simulation source lists.
module cvwsoc_sim_models #(
  parameter cvwsoc_cfg_t C
) (
  input  logic       rst_ni,

  // SD card: present whenever the configured SoC has an SDHCI controller.
  input  logic       SD_CLK,
  output logic       SD_CD_N,
  inout  tri1        SD_CMD,
  inout  tri1 [3:0]  SD_DAT,

  // The SoC supplies the I2S receive clocks; the simulated ADC supplies data.
  input  logic       i2s_rx_sclk,
  input  logic       i2s_rx_lrck,
  output logic       i2s_rx_sdin
);
  localparam cvw_t P = C.wally;

  if (P.AXI_SDHCI_SUPPORTED) begin : gen_sd_card
    // sd_card adapts separate input/output/enable signals. At this boundary
    // those signals have already been resolved onto bidirectional pins.
    // The tri1 ports provide the card bus pull-ups. sdModel retains its
    // existing +SD_IMAGE selection and protocol-driven reset behavior.
    sdModel i_sd_card (
      .sdClk ( SD_CLK ),
      .cmd   ( SD_CMD ),
      .dat   ( SD_DAT )
    );
    assign SD_CD_N = 1'b0;
  end else begin : gen_no_sd_card
    assign SD_CD_N = 1'b1;
  end

  if (P.AXIS_I2S_SUPPORTED) begin : gen_i2s_source
    // Defaults: signed 24-bit stereo, nominal 44.1 kHz, 440/880 Hz tones.
    // No TX DMA is required. Only the serial clocks and reset are inputs.
    i2s_sine_source i_sine_source (
      .rst_ni ( rst_ni       ),
      .sclk_i ( i2s_rx_sclk  ),
      .lrck_i ( i2s_rx_lrck  ),
      .sdin_o ( i2s_rx_sdin  )
    );
  end else begin : gen_no_i2s_source
    assign i2s_rx_sdin = 1'b0;
  end
endmodule
