
# Basic AHB-AXI bridge debugging

# #ila_add_probe u_ila_spi -bus ahbaxibridge/state -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/rd_buf_valid
# ila_add_probe u_ila_spi -bus ahbaxibridge/rd_buf_data -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/ar_done
# ila_add_probe u_ila_spi -net ahbaxibridge/rd_d_entry
# ila_add_probe u_ila_spi -net ahbaxibridge/rd_fence_seen_idle
# ila_add_probe u_ila_spi -net ahbaxibridge/pnd_valid
# ila_add_probe u_ila_spi -net ahbaxibridge/incr_rd
# ila_add_probe u_ila_spi -bus ahbaxibridge/beat_cnt -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/aw_sent
# ila_add_probe u_ila_spi -net ahbaxibridge/incr_wr_cont
# ila_add_probe u_ila_spi -bus ahbaxibridge/acc_cnt -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/flush_ptr -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/raw_r_capture
# ila_add_probe u_ila_spi -net ahbaxibridge/raw_r_accept


# ----------------------------------------------------------------------
# extra bridge debugging signals
# ----------------------------------------------------------------------

# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_trip
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_cause -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_rd_outstanding
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_wr_outstanding
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_cycle_counter -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_cycle -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_ap_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_beat_cnt -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_acc_cnt -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_flush_ptr -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_htrans -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_trip_hwrite
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_trip_rresp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_trip_rlast

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_prev_state -msb 4 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ahb_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ahb_size -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ahb_burst -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ahb_trans -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_last_ahb_write
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ahb_prot -msb 3 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_hwd_data -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_hwd_strb -msb 7 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ar_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ar_len -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ar_size -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_ar_burst -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_r_data -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_r_resp -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_last_r_last
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_last_r_was_capture
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_r_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_r_beat_cnt -msb 7 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_aw_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_aw_len -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_aw_size -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_aw_burst -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_w_data -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_w_strb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_last_w_last
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_w_flush_ptr -msb 3 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_last_b_resp -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist0_code -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist0_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist0_ap_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist0_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist0_beat_cnt -msb 7 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist1_code -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist1_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist1_ap_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist1_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist1_beat_cnt -msb 7 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist2_code -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist2_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist2_ap_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist2_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist2_beat_cnt -msb 7 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist3_code -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist3_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist3_ap_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist3_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_hist3_beat_cnt -msb 7 -lsb 0 -order lsb2msb

# # debug2 delta: source-focused bridge probes

# ila_add_probe u_ila_spi -net ahbaxibridge/ahb_wphase_valid
# ila_add_probe u_ila_spi -net ahbaxibridge/fix_ahb_fire

# ila_add_probe u_ila_spi -net ahbaxibridge/hsel_q
# ila_add_probe u_ila_spi -net ahbaxibridge/hreadyin_q
# ila_add_probe u_ila_spi -bus ahbaxibridge/haddr_q -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/hsize_q -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/htrans_q -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/hwrite_q

# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_live_interleave
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_q_interleave

# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_fix_write_unproven
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_fix_write_cycle -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_fix_write_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_fix_write_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_fix_write_htrans -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_fix_write_hwrite
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_fix_write_hreadyin
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_fix_write_ahb_wphase_valid
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_fix_write_pnd_wfirst_valid
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_fix_write_hwd_data -msb 63 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_fix_write_hwd_strb -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_fix_write_acc_cnt -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_fix_write_flush_ptr -msb 3 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_rd_pop_while_not_ready
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_pop_cycle -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_pop_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_pop_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_pop_beat_cnt -msb 7 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_rd_pop_hready
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_pop_resp -msb 1 -lsb 0 -order lsb2msb

# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_rd_live_q_disagree
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_live_q_cycle -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_live_q_state -msb 4 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_live_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_q_haddr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_live_htrans -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_q_htrans -msb 1 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_rd_live_hwrite
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_rd_q_hwrite
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_live_hsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_q_hsize -msb 2 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_live_ap_addr -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_live_ap_size -msb 2 -lsb 0 -order lsb2msb

# #v11 extras
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_pnd_align_unproven
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_pnd_flush_unproven
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_rd_repeat_deliver
# ila_add_probe u_ila_spi -net ahbaxibridge/dbg_rd_lastbeat_no_deliver
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_pnd_align_cycle -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_pnd_flush_cycle -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_repeat_cycle -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_lastbeat_cycle -msb 31 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_buf_capture_seq_dbg -msb 15 -lsb 0 -order lsb2msb
# ila_add_probe u_ila_spi -bus ahbaxibridge/dbg_rd_last_deliver_seq_dbg -msb 15 -lsb 0 -order lsb2msb

# ----------------------------------------------------------------------
# Passive AHB/AXI performance counters
#
# All counters are 32-bit wrapping values sampled by the ILA.  Compare
# snapshots rather than waveform samples: delta(counter) / delta(cycles)
# is the useful throughput or stall ratio.
# ----------------------------------------------------------------------

# AXI traffic and channel-level backpressure.
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_aw_transactions -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_ar_transactions -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_w_beats -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_r_beats -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_b_responses -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_aw_stall_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_w_stall_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_b_stall_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_ar_stall_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_r_stall_cycles -msb 31 -lsb 0 -order lsb2msb

# AXI transaction latency and absent-valid bubble counters.
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_write_data_bubble_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_write_b_wait_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_read_first_r_wait_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_read_r_bubble_cycles -msb 31 -lsb 0 -order lsb2msb

# AXI burst-length distribution (AW and AR separately).
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_aw_single_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_aw_incr4_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_aw_incr8_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_aw_incr16_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_aw_other_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_ar_single_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_ar_incr4_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_ar_incr8_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_ar_incr16_bursts -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_axi_ar_other_bursts -msb 31 -lsb 0 -order lsb2msb

# AHB-side activity and bridge-local attribution.
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_active_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_accepted_beats -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_write_beats -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_read_beats -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_ready_stall_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_upstream_stall_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_fixed_incr4_writes -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_fixed_incr8_writes -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_fixed_incr16_writes -msb 31 -lsb 0 -order lsb2msb
# AHB HPROT classification of fixed INCR8 read fills: instruction/data and
# cacheable/non-cacheable are protocol hints, not cache-origin proof.
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_fixed_incr8_instr_reads -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_fixed_incr8_data_reads -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_fixed_incr8_cacheable_reads -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_fixed_incr8_noncacheable_reads -msb 31 -lsb 0 -order lsb2msb
# Undefined-length AHB INCR traffic before the bridge chops it into AXI bursts.
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_incr_transactions -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_incr_write_transactions -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_incr_read_transactions -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_incr_beats -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_incr_write_beats -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_ahb_incr_read_beats -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_fixed_write_accumulate_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_fixed_write_flush_cycles -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_fixed_partial_flushes -msb 31 -lsb 0 -order lsb2msb
ila_add_probe u_ila_spi -bus ahbaxibridge/gen_perf_probes.perf_read_queue_full_stall_cycles -msb 31 -lsb 0 -order lsb2msb
