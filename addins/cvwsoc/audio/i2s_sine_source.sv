`timescale 1ns/1ps

// Simulation-only ADC stimulus: signed 24-bit stereo PCM in 32-bit I2S slots.
// Generate the table once; advancing the tones requires only integer arithmetic.
module i2s_sine_source #(
  parameter int unsigned SampleRate = 44100,
  parameter int unsigned LeftHz = 440,
  parameter int unsigned RightHz = 880
) (
  input  logic rst_ni,
  input  logic sclk_i,
  input  logic lrck_i,
  output logic sdin_o
);
  localparam int unsigned TableBits = 10;
  localparam int unsigned TableSize = 1 << TableBits;
  localparam logic [31:0] LeftStep =
      32'(((64'(LeftHz) << 32) + SampleRate / 2) / SampleRate);
  localparam logic [31:0] RightStep =
      32'(((64'(RightHz) << 32) + SampleRate / 2) / SampleRate);

  logic signed [23:0] sine_table [TableSize];
  logic [31:0] left_phase, right_phase;
  logic [23:0] left_sample, right_sample;
  logic last_lrck;
  logic [5:0] slot_bit;

  initial begin
    assert (SampleRate > 0 && LeftHz > 0 && RightHz > 0 &&
            LeftHz < SampleRate / 2 && RightHz < SampleRate / 2)
      else $fatal(1, "i2s_sine_source: tones must be below Nyquist");
    for (int i = 0; i < TableSize; i++)
      sine_table[i] = 24'($rtoi(4194303.0 *
          $sin(6.283185307179586 * real'(i) / real'(TableSize))));
  end

  // LRCK=0 is left. At a channel boundary emit the I2S delay bit, then
  // 24 data bits MSB-first and seven padding bits. Update both tones only
  // once per stereo frame, independently of DMA readiness or TX activity.
  always @(negedge sclk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      left_phase <= '0;
      right_phase <= '0;
      left_sample <= '0;
      right_sample <= '0;
      last_lrck <= 1'b1;
      slot_bit <= '0;
      sdin_o <= 1'b0;
    end else if (lrck_i != last_lrck) begin
      last_lrck <= lrck_i;
      slot_bit <= 1;
      sdin_o <= 1'b0;
      if (!lrck_i) begin
        left_sample <= sine_table[left_phase[31 -: TableBits]];
        right_sample <= sine_table[right_phase[31 -: TableBits]];
        left_phase <= left_phase + LeftStep;
        right_phase <= right_phase + RightStep;
      end
    end else begin
      if (slot_bit >= 1 && slot_bit <= 24)
        sdin_o <= lrck_i ? right_sample[24-slot_bit] : left_sample[24-slot_bit];
      else
        sdin_o <= 1'b0;
      if (slot_bit < 31)
        slot_bit <= slot_bit + 1'b1;
    end
  end
endmodule
