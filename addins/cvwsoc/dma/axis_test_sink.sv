///////////////////////////////////////////
// axis_test_sink.sv
//
// Simulation sink for the iDMA DDR-to-AXI-Stream playback path.
///////////////////////////////////////////

module axis_test_sink #(
  parameter int unsigned DataWidth = 64,
  parameter type axis_req_t = logic,
  parameter type axis_rsp_t = logic
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  axis_req_t   axis_req_i,
  output axis_rsp_t   axis_rsp_o,
  input  logic [31:0] stall_period_i,
  input  logic [31:0] stall_cycles_i,
  input  logic        report_i,
  output logic [63:0] accepted_byte_count_o,
  output logic        data_error_o,
  output logic        tkeep_error_o,
  output logic        tlast_error_o,
  output logic        stability_error_o
);

  localparam int unsigned StrbWidth = DataWidth / 8;

  logic [31:0] stall_phase_q;
  logic [63:0] expected_byte_index_q;
  logic stalled_q;
  axis_req_t stalled_req_q;

  logic ready;
  logic transfer;
  logic [StrbWidth-1:0] keep;

  assign ready = (stall_period_i == 0) || (stall_cycles_i == 0) ||
                 (stall_phase_q >= stall_cycles_i);
  assign axis_rsp_o.tready = ready;
  assign transfer = axis_req_i.tvalid && ready;
  assign keep = axis_req_i.t.keep;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      stall_phase_q <= '0;
    end else if ((stall_period_i == 0) || (stall_cycles_i == 0) ||
                 (stall_phase_q + 1 >= stall_period_i)) begin
      stall_phase_q <= '0;
    end else begin
      stall_phase_q <= stall_phase_q + 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : check_stream
    logic [63:0] next_expected_index;
    logic seen_invalid_lane;

    if (!rst_ni) begin
      accepted_byte_count_o <= '0;
      expected_byte_index_q <= '0;
      data_error_o <= 1'b0;
      tkeep_error_o <= 1'b0;
      tlast_error_o <= 1'b0;
      stability_error_o <= 1'b0;
      stalled_q <= 1'b0;
      stalled_req_q <= '0;
    end else begin
      if (stalled_q && (axis_req_i !== stalled_req_q))
        stability_error_o <= 1'b1;

      if (axis_req_i.tvalid && !ready) begin
        if (!stalled_q)
          stalled_req_q <= axis_req_i;
        stalled_q <= 1'b1;
      end else begin
        stalled_q <= 1'b0;
      end

      if (transfer) begin
        next_expected_index = expected_byte_index_q;
        seen_invalid_lane = 1'b0;

        if (keep == '0)
          tkeep_error_o <= 1'b1;
        if (axis_req_i.t.last)
          tlast_error_o <= 1'b1;

        for (int unsigned lane = 0; lane < StrbWidth; lane++) begin
          if (keep[lane]) begin
            // Playback data is packed into low-to-high byte lanes.  A valid
            // lane after a hole is therefore an invalid TKEEP shape.
            if (seen_invalid_lane)
              tkeep_error_o <= 1'b1;
            if (axis_req_i.t.data[lane*8 +: 8] !==
                (next_expected_index[7:0] ^ 8'hA5))
              data_error_o <= 1'b1;
            next_expected_index = next_expected_index + 1'b1;
          end else begin
            seen_invalid_lane = 1'b1;
          end
        end

        expected_byte_index_q <= next_expected_index;
        accepted_byte_count_o <= accepted_byte_count_o +
                                 $countones(keep);
      end

      if (report_i) begin
        $display("AXIS_SINK accepted=%0d data_error=%0b tkeep_error=%0b tlast_error=%0b stability_error=%0b",
                 accepted_byte_count_o, data_error_o, tkeep_error_o,
                 tlast_error_o, stability_error_o);
        accepted_byte_count_o <= '0;
        expected_byte_index_q <= '0;
        data_error_o <= 1'b0;
        tkeep_error_o <= 1'b0;
        tlast_error_o <= 1'b0;
        stability_error_o <= 1'b0;
      end
    end
  end

endmodule
