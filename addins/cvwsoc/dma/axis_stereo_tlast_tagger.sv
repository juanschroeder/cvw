///////////////////////////////////////////
// axis_stereo_tlast_tagger.sv
//
// Marks every second 32-bit sample as the right-channel/end-of-frame word.
///////////////////////////////////////////

module axis_stereo_tlast_tagger (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [31:0] s_axis_tdata,
  input  logic        s_axis_tvalid,
  output logic        s_axis_tready,
  output logic [31:0] m_axis_tdata,
  output logic        m_axis_tvalid,
  input  logic        m_axis_tready,
  output logic        m_axis_tlast
);

  logic right_channel_q;

  assign s_axis_tready = m_axis_tready;
  assign m_axis_tdata  = s_axis_tdata;
  assign m_axis_tvalid = s_axis_tvalid;
  assign m_axis_tlast  = right_channel_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      right_channel_q <= 1'b0;
    else if (m_axis_tvalid && m_axis_tready)
      right_channel_q <= ~right_channel_q;
  end

endmodule
