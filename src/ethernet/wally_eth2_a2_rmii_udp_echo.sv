// wally_eth_a2_rmii_udp_echo.sv
// A2: RMII (via rmii_phy_if) -> MII -> eth_mac_mii_fifo -> udp_complete -> UDP echo
// No AXI, no Wally SoC

`timescale 1ns/1ps

module wally_eth_a2_rmii_udp_echo #(
    // Default config (same style as verilog-ethernet examples)
    parameter logic [47:0] LOCAL_MAC   = 48'h02_00_00_00_00_01,
    parameter logic [31:0] LOCAL_IP    = {8'd192,8'd168,8'd178,8'd130},
    parameter logic [31:0] GATEWAY_IP  = {8'd192,8'd168,8'd178,8'd1},
    parameter logic [31:0] SUBNET_MASK = {8'd255,8'd255,8'd255,8'd0},
    parameter logic [15:0] UDP_PORT    = 16'd1234
) (
    // RMII pins (your existing top-level names)
    input  logic        eth_ref_clk,          // 50 MHz from PMOD/PHY
    input  logic [1:0]  eth_rx_data,
    input  logic        eth_crs_dv,
    output logic [1:0]  eth_tx_data,
    output logic        eth_tx_en,

    // Simple LED outputs to map to GPO[2:0]
    output logic [2:0]  eth_led
    , output logic        eth_mdc,
    inout  wire         eth_mdio    
);

    // ------------------------------------------------------------------------
    // Clock / reset (use eth_ref_clk as the single logic clock)
    // ------------------------------------------------------------------------
    logic clk;

    // --------------------------------------------------------------------------------------------
    // 1) Make the non-clock-capable pin usable as a clock (we'll BUFG it; XDC will relax routing)
    // --------------------------------------------------------------------------------------------
    //assign clk = eth_ref_clk;
    assign clk = eth_ref_clk_buf;


    wire eth_ref_clk_i;
    IBUF u_ibuf_refclk (.I(eth_ref_clk), .O(eth_ref_clk_i));

    wire eth_ref_clk_buf;
    BUFG u_bufg_refclk (.I(eth_ref_clk_i), .O(eth_ref_clk_buf));


    // Power-on reset stretch ~20ms @ 50 MHz
    logic rst;
    logic [19:0] por_cnt = '0;

    always_ff @(posedge clk) begin
        if (!por_cnt[19]) begin
            por_cnt <= por_cnt + 1'b1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end

    // Heartbeat LED ~1 Hz (toggle each 0.5s => visible blink)
    logic [25:0] hb_cnt = '0;
    logic hb_led = 1'b0;

    always_ff @(posedge clk) begin
        if (rst) begin
            hb_cnt <= '0;
            hb_led <= 1'b0;
        end else begin
            if (hb_cnt == 26'd24_999_999) begin
                hb_cnt <= '0;
                hb_led <= ~hb_led;
            end else begin
                hb_cnt <= hb_cnt + 1'b1;
            end
        end
    end


    ///////////////////////////////////////////////////////////////////////////
        // ------------------------------------------------------------------------
        // MDIO init for LAN8720 (PHY addr 0): soft reset + restart autoneg, then read link
        // ------------------------------------------------------------------------

        logic mdc = 1'b0;
        logic mdio_drive_low = 1'b0;   // 1 = drive MDIO low, 0 = Hi-Z (pulled up externally)
        wire  mdio_in;

        IOBUF u_mdio_iobuf (
            .I (1'b0),
            .O (mdio_in),
            .T (~mdio_drive_low),
            .IO(eth_mdio)
        );

        assign eth_mdc = mdc;

        // Generate MDC ~2.5 MHz from 50 MHz clk (divide by 20, toggle every 10 cycles)
        logic [3:0] mdc_div = '0;
        logic mdc_rise = 1'b0;
        logic mdc_fall = 1'b0;

        always_ff @(posedge clk) begin
            mdc_rise <= 1'b0;
            mdc_fall <= 1'b0;
            if (rst) begin
                mdc_div <= '0;
                mdc <= 1'b0;
            end else begin
                if (mdc_div == 4'd9) begin
                    mdc_div <= '0;
                    mdc <= ~mdc;
                    if (!mdc) mdc_rise <= 1'b1; // 0->1
                    else      mdc_fall <= 1'b1; // 1->0
                end else begin
                    mdc_div <= mdc_div + 1'b1;
                end
            end
        end

        // Clause-22 MDIO master: minimal ops we need
        typedef enum logic [4:0] {
            STATE_IDLE,
            ST_PREAMBLE,
            ST_START0, ST_START1,
            ST_OP0, ST_OP1,
            ST_PHYAD,
            ST_REGAD,
            ST_TA0, ST_TA1,
            ST_DATA,
            ST_DONE,
            ST_GAP
        } mdio_state_t;

        mdio_state_t mdst = STATE_IDLE;

        logic        mdio_is_read = 1'b0;
        logic [4:0]  mdio_reg = 5'd0;
        logic [15:0] mdio_wr = 16'h0000;
        logic [15:0] mdio_rd = 16'h0000;

        logic [5:0]  pre_cnt = 6'd0;
        logic [4:0]  bit_cnt = 5'd0;
        logic [15:0] shreg = 16'h0000;

        logic        mdio_start = 1'b0;
        logic        mdio_busy  = 1'b0;
        logic        mdio_done  = 1'b0;

        // link status (BMSR bit[2])
        logic link_up = 1'b0;

        // Kick sequence: after reset, do reset+autoneg, then poll link
        typedef enum logic [2:0] {SEQ_RESET, SEQ_ANEG, SEQ_POLL, SEQ_WAIT} seq_t;
        seq_t seq = SEQ_RESET;

        logic [23:0] wait_cnt = '0; // ~0.3s max delay if needed

        always_ff @(posedge clk) begin
            if (rst) begin
                seq <= SEQ_RESET;
                mdio_start <= 1'b0;
                wait_cnt <= '0;
            end else begin
                mdio_start <= 1'b0;

                case (seq)
                    // 1) Soft reset: BMCR (reg0) bit15 = 1
                    SEQ_RESET: begin
                        if (!mdio_busy) begin
                            mdio_is_read <= 1'b0;
                            mdio_reg <= 5'd0;
                            mdio_wr <= 16'h8000;
                            mdio_start <= 1'b1;
                            seq <= SEQ_WAIT;
                            wait_cnt <= 24'd5_000_000; // ~0.1s
                        end
                    end

                    // 2) Restart autoneg: BMCR = 0x1200 (AN enable + restart)
                    SEQ_ANEG: begin
                        if (!mdio_busy) begin
                            mdio_is_read <= 1'b0;
                            mdio_reg <= 5'd0;
                            mdio_wr <= 16'h1200;
                            mdio_start <= 1'b1;
                            seq <= SEQ_WAIT;
                            wait_cnt <= 24'd5_000_000; // ~0.1s
                        end
                    end

                    // 3) Poll BMSR (reg1) for link bit
                    SEQ_POLL: begin
                        if (!mdio_busy) begin
                            mdio_is_read <= 1'b1;
                            mdio_reg <= 5'd1;
                            mdio_start <= 1'b1;
                            seq <= SEQ_WAIT;
                            wait_cnt <= 24'd2_500_000; // ~0.05s between polls
                        end
                    end

                    // Wait between steps; on completion decide next
                    SEQ_WAIT: begin
                        if (mdio_done) begin
                            if (mdio_is_read) begin
                                link_up <= mdio_rd[2];
                                seq <= SEQ_POLL;
                            end else begin
                                seq <= (seq == SEQ_WAIT && mdio_wr == 16'h8000) ? SEQ_ANEG : SEQ_POLL;
                            end
                        end else if (wait_cnt != 0) begin
                            wait_cnt <= wait_cnt - 1'b1;
                        end
                    end

                    default: seq <= SEQ_RESET;
                endcase
            end
        end

        // MDIO transaction engine (advances on MDC edges)
        always_ff @(posedge clk) begin
            if (rst) begin
                mdst <= STATE_IDLE;
                mdio_drive_low <= 1'b0;
                mdio_busy <= 1'b0;
                mdio_done <= 1'b0;
                pre_cnt <= '0;
                bit_cnt <= '0;
                mdio_rd <= 16'h0000;
            end else begin
                mdio_done <= 1'b0;

                // Launch transaction
                if (mdio_start && !mdio_busy) begin
                    mdio_busy <= 1'b1;
                    mdst <= ST_PREAMBLE;
                    pre_cnt <= 6'd32;
                    bit_cnt <= 5'd0;
                    mdio_rd <= 16'h0000;
                end

                // Drive MDIO on falling edge so it is stable for rising edge sampling
                if (mdio_busy && mdc_fall) begin
                    unique case (mdst)
                        ST_PREAMBLE: begin
                            // send '1' => Hi-Z
                            mdio_drive_low <= 1'b0;
                            pre_cnt <= pre_cnt - 1'b1;
                            if (pre_cnt == 6'd1) mdst <= ST_START0;
                        end
                        ST_START0: begin
                            // start = 0
                            mdio_drive_low <= 1'b1;
                            mdst <= ST_START1;
                        end
                        ST_START1: begin
                            // start = 1
                            mdio_drive_low <= 1'b0;
                            mdst <= ST_OP0;
                        end
                        ST_OP0: begin
                            // op[1]: write=0, read=1
                            mdio_drive_low <= (mdio_is_read ? 1'b0 : 1'b1); // read:1=>Z, write:0=>drive low
                            mdst <= ST_OP1;
                        end
                        ST_OP1: begin
                            // op[0]: write=1, read=0
                            mdio_drive_low <= (mdio_is_read ? 1'b1 : 1'b0); // read:0=>drive low, write:1=>Z
                            mdst <= ST_PHYAD;
                            bit_cnt <= 5'd5;
                        end
                        ST_PHYAD: begin
                            // PHY addr = 0 => all zeros (drive low for 5 bits)
                            mdio_drive_low <= 1'b1;
                            bit_cnt <= bit_cnt - 1'b1;
                            if (bit_cnt == 5'd1) begin
                                mdst <= ST_REGAD;
                                bit_cnt <= 5'd5;
                            end
                        end
                        ST_REGAD: begin
                            // reg addr MSB first
                            mdio_drive_low <= ~mdio_reg[bit_cnt-1]; // 0->drive low, 1->Z
                            bit_cnt <= bit_cnt - 1'b1;
                            if (bit_cnt == 5'd1) begin
                                mdst <= ST_TA0;
                            end
                        end
                        ST_TA0: begin
                            // Turnaround
                            mdio_drive_low <= (mdio_is_read ? 1'b0 : 1'b0); // read: release (Z) handled by TA1, write: first TA bit = 1 (Z)
                            // For write, first TA bit is '1' => Z, so mdio_drive_low=0 is fine.
                            mdst <= ST_TA1;
                        end
                        ST_TA1: begin
                            if (mdio_is_read) begin
                                // read: release bus for TA (Z)
                                mdio_drive_low <= 1'b0;
                                mdst <= ST_DATA;
                                bit_cnt <= 5'd16;
                            end else begin
                                // write: second TA bit = 0 (drive low), then data
                                mdio_drive_low <= 1'b1;
                                mdst <= ST_DATA;
                                bit_cnt <= 5'd16;
                                shreg <= mdio_wr;
                            end
                        end
                        ST_DATA: begin
                            if (mdio_is_read) begin
                                // keep released during read data
                                mdio_drive_low <= 1'b0;
                            end else begin
                                // write data MSB first
                                mdio_drive_low <= ~shreg[15];
                                shreg <= {shreg[14:0], 1'b0};
                            end
                            bit_cnt <= bit_cnt - 1'b1;
                            if (bit_cnt == 5'd1) mdst <= ST_DONE;
                        end
                        ST_DONE: begin
                            mdio_drive_low <= 1'b0; // release
                            mdst <= ST_GAP;
                            pre_cnt <= 6'd8;        // small idle gap
                        end
                        ST_GAP: begin
                            mdio_drive_low <= 1'b0;
                            pre_cnt <= pre_cnt - 1'b1;
                            if (pre_cnt == 6'd1) begin
                                mdio_busy <= 1'b0;
                                mdio_done <= 1'b1;
                                mdst <= STATE_IDLE;
                            end
                        end
                        default: ;
                    endcase
                end

                // Sample MDIO on rising edge during read data
                if (mdio_busy && mdio_is_read && mdc_rise) begin
                    if (mdst == ST_DATA && bit_cnt != 0) begin
                        mdio_rd <= {mdio_rd[14:0], mdio_in};
                    end
                end
            end
        end


    ///////////////////////////////////////////////////////////////////////////


    // ------------------------------------------------------------------------
    // RMII -> MII shim (WangXuan rmii_phy_if.v)
    // ------------------------------------------------------------------------
    logic        mii_rx_clk;
    logic [3:0]  mii_rxd;
    logic        mii_rx_dv;
    logic        mii_rx_er;

    logic        mii_tx_clk;
    logic [3:0]  mii_txd;
    logic        mii_tx_en;
    logic        mii_tx_er;

    rmii_phy_if u_rmii_phy_if (
        .rstn_async       (~rst),
        .mode_speed       (1'b1),          // force 100M for A2 (same idea as A1)

        // MII-side (toward verilog-ethernet MAC)
        .mac_mii_crs      (),              // unused by eth_mac_mii_fifo
        .mac_mii_rxrst    (),              // optional; not used in A2
        .mac_mii_rxc      (mii_rx_clk),
        .mac_mii_rxdv     (mii_rx_dv),
        .mac_mii_rxer     (mii_rx_er),
        .mac_mii_rxd      (mii_rxd),

        .mac_mii_txrst    (),              // optional; not used in A2
        .mac_mii_txc      (mii_tx_clk),
        .mac_mii_txen     (mii_tx_en),
        .mac_mii_txer     (mii_tx_er),
        .mac_mii_txd      (mii_txd),

        // RMII-side (toward PHY/PMOD)
        .phy_rmii_ref_clk (eth_ref_clk_buf),
        .phy_rmii_crsdv   (eth_crs_dv),
        .phy_rmii_rxer    (1'b0),          // you don't have RXER on the PMOD header
        .phy_rmii_rxd     (eth_rx_data),

        .phy_rmii_txen    (eth_tx_en),
        .phy_rmii_txd     (eth_tx_data)
    );

    // ------------------------------------------------------------------------
    // verilog-ethernet MAC: MII <-> AXI-stream Ethernet frames (8-bit)
    // ------------------------------------------------------------------------
    logic [7:0] mac_tx_axis_tdata;
    logic       mac_tx_axis_tvalid;
    logic       mac_tx_axis_tready;
    logic       mac_tx_axis_tlast;
    logic       mac_tx_axis_tuser;
    logic [0:0] mac_tx_axis_tkeep;

    logic [7:0] mac_rx_axis_tdata;
    logic       mac_rx_axis_tvalid;
    logic       mac_rx_axis_tready;
    logic       mac_rx_axis_tlast;
    logic       mac_rx_axis_tuser;
    logic [0:0] mac_rx_axis_tkeep;

    assign mac_tx_axis_tkeep = 1'b1; // always valid bytes on 8-bit axis

    eth_mac_mii_fifo #(
        .TARGET("XILINX"),
        //.CLOCK_INPUT_STYLE("BUFR"),
        .CLOCK_INPUT_STYLE("BUFG"),
        .AXIS_DATA_WIDTH(8),
        .ENABLE_PADDING(1),
        .MIN_FRAME_LENGTH(64),
        .TX_FIFO_DEPTH(4096),
        .TX_FRAME_FIFO(1),
        .RX_FIFO_DEPTH(4096),
        .RX_FRAME_FIFO(1)
    ) u_mac (
        .rst(rst),
        .logic_clk(clk),
        .logic_rst(rst),

        .tx_axis_tdata(mac_tx_axis_tdata),
        .tx_axis_tkeep(mac_tx_axis_tkeep),
        .tx_axis_tvalid(mac_tx_axis_tvalid),
        .tx_axis_tready(mac_tx_axis_tready),
        .tx_axis_tlast(mac_tx_axis_tlast),
        .tx_axis_tuser(mac_tx_axis_tuser),

        .rx_axis_tdata(mac_rx_axis_tdata),
        .rx_axis_tkeep(mac_rx_axis_tkeep),
        .rx_axis_tvalid(mac_rx_axis_tvalid),
        .rx_axis_tready(mac_rx_axis_tready),
        .rx_axis_tlast(mac_rx_axis_tlast),
        .rx_axis_tuser(mac_rx_axis_tuser),

        .mii_rx_clk(mii_rx_clk),
        .mii_rxd(mii_rxd),
        .mii_rx_dv(mii_rx_dv),
        .mii_rx_er(mii_rx_er),

        .mii_tx_clk(mii_tx_clk),
        .mii_txd(mii_txd),
        .mii_tx_en(mii_tx_en),
        .mii_tx_er(mii_tx_er),

        .tx_error_underflow(),
        .tx_fifo_overflow(),
        .tx_fifo_bad_frame(),
        .tx_fifo_good_frame(),

        .rx_error_bad_frame(),
        .rx_error_bad_fcs(),
        .rx_fifo_overflow(),
        .rx_fifo_bad_frame(),
        .rx_fifo_good_frame(),

        //.ifg_delay(8'd12)
        .cfg_ifg(8'd12),
        //.cfg_tx_enable(1'b1),
        // Test for LEDs and link detection
        .cfg_tx_enable(1'b0),
        .cfg_rx_enable(1'b1)
    );

    // ------------------------------------------------------------------------
    // Ethernet frame parse/compose (axis <-> eth_hdr + payload axis)
    // ------------------------------------------------------------------------
    logic        rx_eth_hdr_valid, rx_eth_hdr_ready;
    logic [47:0] rx_eth_dest_mac, rx_eth_src_mac;
    logic [15:0] rx_eth_type;
    logic [7:0]  rx_eth_payload_axis_tdata;
    logic        rx_eth_payload_axis_tvalid;
    logic        rx_eth_payload_axis_tready;
    logic        rx_eth_payload_axis_tlast;
    logic        rx_eth_payload_axis_tuser;

    eth_axis_rx u_eth_axis_rx (
        .clk(clk),
        .rst(rst),

        .s_axis_tdata(mac_rx_axis_tdata),
        .s_axis_tvalid(mac_rx_axis_tvalid),
        .s_axis_tready(mac_rx_axis_tready),
        .s_axis_tlast(mac_rx_axis_tlast),
        .s_axis_tuser(mac_rx_axis_tuser),

        .m_eth_hdr_valid(rx_eth_hdr_valid),
        .m_eth_hdr_ready(rx_eth_hdr_ready),
        .m_eth_dest_mac(rx_eth_dest_mac),
        .m_eth_src_mac(rx_eth_src_mac),
        .m_eth_type(rx_eth_type),

        .m_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
        .m_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
        .m_eth_payload_axis_tready(rx_eth_payload_axis_tready),
        .m_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
        .m_eth_payload_axis_tuser(rx_eth_payload_axis_tuser)
    );

    logic        tx_eth_hdr_valid, tx_eth_hdr_ready;
    logic [47:0] tx_eth_dest_mac, tx_eth_src_mac;
    logic [15:0] tx_eth_type;
    logic [7:0]  tx_eth_payload_axis_tdata;
    logic        tx_eth_payload_axis_tvalid;
    logic        tx_eth_payload_axis_tready;
    logic        tx_eth_payload_axis_tlast;
    logic        tx_eth_payload_axis_tuser;

    eth_axis_tx u_eth_axis_tx (
        .clk(clk),
        .rst(rst),

        .s_eth_hdr_valid(tx_eth_hdr_valid),
        .s_eth_hdr_ready(tx_eth_hdr_ready),
        .s_eth_dest_mac(tx_eth_dest_mac),
        .s_eth_src_mac(tx_eth_src_mac),
        .s_eth_type(tx_eth_type),

        .s_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
        .s_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
        .s_eth_payload_axis_tready(tx_eth_payload_axis_tready),
        .s_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
        .s_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),

        .m_axis_tdata(mac_tx_axis_tdata),
        .m_axis_tvalid(mac_tx_axis_tvalid),
        .m_axis_tready(mac_tx_axis_tready),
        .m_axis_tlast(mac_tx_axis_tlast),
        .m_axis_tuser(mac_tx_axis_tuser)
    );

    // ------------------------------------------------------------------------
    // UDP/IP/ARP stack
    // ------------------------------------------------------------------------
    logic        rx_udp_hdr_valid, rx_udp_hdr_ready;
    logic [5:0]  rx_udp_ip_dscp;
    logic [1:0]  rx_udp_ip_ecn;
    logic [7:0]  rx_udp_ip_ttl;
    logic [31:0] rx_udp_ip_source_ip;
    logic [31:0] rx_udp_ip_dest_ip;
    logic [15:0] rx_udp_source_port;
    logic [15:0] rx_udp_dest_port;
    logic [15:0] rx_udp_length;
    logic [15:0] rx_udp_checksum;
    logic [7:0]  rx_udp_payload_axis_tdata;
    logic        rx_udp_payload_axis_tvalid;
    logic        rx_udp_payload_axis_tready;
    logic        rx_udp_payload_axis_tlast;
    logic        rx_udp_payload_axis_tuser;

    logic        tx_udp_hdr_valid, tx_udp_hdr_ready;
    logic [5:0]  tx_udp_ip_dscp;
    logic [1:0]  tx_udp_ip_ecn;
    logic [7:0]  tx_udp_ip_ttl;
    logic [31:0] tx_udp_ip_source_ip;
    logic [31:0] tx_udp_ip_dest_ip;
    logic [15:0] tx_udp_source_port;
    logic [15:0] tx_udp_dest_port;
    logic [15:0] tx_udp_length;
    logic [15:0] tx_udp_checksum;
    logic [7:0]  tx_udp_payload_axis_tdata;
    logic        tx_udp_payload_axis_tvalid;
    logic        tx_udp_payload_axis_tready;
    logic        tx_udp_payload_axis_tlast;
    logic        tx_udp_payload_axis_tuser;

    udp_complete u_udp_complete (
        .clk(clk),
        .rst(rst),

        // Ethernet frame input from eth_axis_rx
        .s_eth_hdr_valid(rx_eth_hdr_valid),
        .s_eth_hdr_ready(rx_eth_hdr_ready),
        .s_eth_dest_mac(rx_eth_dest_mac),
        .s_eth_src_mac(rx_eth_src_mac),
        .s_eth_type(rx_eth_type),
        .s_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
        .s_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
        .s_eth_payload_axis_tready(rx_eth_payload_axis_tready),
        .s_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
        .s_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),

        // Ethernet frame output to eth_axis_tx
        .m_eth_hdr_valid(tx_eth_hdr_valid),
        .m_eth_hdr_ready(tx_eth_hdr_ready),
        .m_eth_dest_mac(tx_eth_dest_mac),
        .m_eth_src_mac(tx_eth_src_mac),
        .m_eth_type(tx_eth_type),
        .m_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
        .m_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
        .m_eth_payload_axis_tready(tx_eth_payload_axis_tready),
        .m_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
        .m_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),

        // UDP frame input (from our echo app)
        .s_udp_hdr_valid(tx_udp_hdr_valid),
        .s_udp_hdr_ready(tx_udp_hdr_ready),
        .s_udp_ip_dscp(tx_udp_ip_dscp),
        .s_udp_ip_ecn(tx_udp_ip_ecn),
        .s_udp_ip_ttl(tx_udp_ip_ttl),
        .s_udp_ip_source_ip(tx_udp_ip_source_ip),
        .s_udp_ip_dest_ip(tx_udp_ip_dest_ip),
        .s_udp_source_port(tx_udp_source_port),
        .s_udp_dest_port(tx_udp_dest_port),
        .s_udp_length(tx_udp_length),
        .s_udp_checksum(tx_udp_checksum),
        .s_udp_payload_axis_tdata(tx_udp_payload_axis_tdata),
        .s_udp_payload_axis_tvalid(tx_udp_payload_axis_tvalid),
        .s_udp_payload_axis_tready(tx_udp_payload_axis_tready),
        .s_udp_payload_axis_tlast(tx_udp_payload_axis_tlast),
        .s_udp_payload_axis_tuser(tx_udp_payload_axis_tuser),

        // UDP frame output (to our echo app)
        .m_udp_hdr_valid(rx_udp_hdr_valid),
        .m_udp_hdr_ready(rx_udp_hdr_ready),
        .m_udp_ip_dscp(rx_udp_ip_dscp),
        .m_udp_ip_ecn(rx_udp_ip_ecn),
        .m_udp_ip_ttl(rx_udp_ip_ttl),
        .m_udp_ip_source_ip(rx_udp_ip_source_ip),
        .m_udp_ip_dest_ip(rx_udp_ip_dest_ip),
        .m_udp_source_port(rx_udp_source_port),
        .m_udp_dest_port(rx_udp_dest_port),
        .m_udp_length(rx_udp_length),
        .m_udp_checksum(rx_udp_checksum),
        .m_udp_payload_axis_tdata(rx_udp_payload_axis_tdata),
        .m_udp_payload_axis_tvalid(rx_udp_payload_axis_tvalid),
        .m_udp_payload_axis_tready(rx_udp_payload_axis_tready),
        .m_udp_payload_axis_tlast(rx_udp_payload_axis_tlast),
        .m_udp_payload_axis_tuser(rx_udp_payload_axis_tuser),

        // Configuration
        .local_mac(LOCAL_MAC),
        .local_ip(LOCAL_IP),
        .gateway_ip(GATEWAY_IP),
        .subnet_mask(SUBNET_MASK),
        .clear_arp_cache(1'b0)
    );

    // ------------------------------------------------------------------------
    // UDP echo app (streaming, no payload FIFO)
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {ST_IDLE, ST_ECHO, ST_DROP} state_t;
    state_t st = ST_IDLE;

    logic match_port;
    assign match_port = (rx_udp_dest_port == UDP_PORT);

    // combinational “active this cycle” so we don’t drop the first payload byte
    logic echo_active;
    logic drop_active;

    always_comb begin
        echo_active = (st == ST_ECHO) ||
                      (st == ST_IDLE && rx_udp_hdr_valid && match_port && tx_udp_hdr_ready);
        drop_active = (st == ST_DROP) ||
                      (st == ST_IDLE && rx_udp_hdr_valid && !match_port);

        // defaults
        rx_udp_hdr_ready = 1'b0;

        tx_udp_hdr_valid = 1'b0;
        tx_udp_ip_dscp   = 6'd0;
        tx_udp_ip_ecn    = 2'd0;
        tx_udp_ip_ttl    = 8'd64;
        tx_udp_ip_source_ip = rx_udp_ip_dest_ip;   // should equal LOCAL_IP
        tx_udp_ip_dest_ip   = rx_udp_ip_source_ip; // reply to sender
        tx_udp_source_port  = rx_udp_dest_port;
        tx_udp_dest_port    = rx_udp_source_port;
        tx_udp_length       = rx_udp_length;
        tx_udp_checksum     = 16'd0; // IPv4 UDP checksum can be 0 (disabled)

        // payload defaults
        tx_udp_payload_axis_tdata  = rx_udp_payload_axis_tdata;
        tx_udp_payload_axis_tvalid = 1'b0;
        tx_udp_payload_axis_tlast  = rx_udp_payload_axis_tlast;
        tx_udp_payload_axis_tuser  = rx_udp_payload_axis_tuser;

        rx_udp_payload_axis_tready = 1'b0;

        if (st == ST_IDLE) begin
            if (rx_udp_hdr_valid) begin
                if (match_port) begin
                    // Only accept RX header when we can also push TX header immediately
                    if (tx_udp_hdr_ready) begin
                        rx_udp_hdr_ready = 1'b1;
                        tx_udp_hdr_valid = 1'b1;
                    end
                end else begin
                    // accept and drop
                    rx_udp_hdr_ready = 1'b1;
                end
            end
        end

        // Streaming echo
        if (echo_active) begin
            tx_udp_payload_axis_tvalid = rx_udp_payload_axis_tvalid;
            rx_udp_payload_axis_tready = tx_udp_payload_axis_tready;
        end else if (drop_active) begin
            // Drain payload
            rx_udp_payload_axis_tready = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            st <= ST_IDLE;
        end else begin
            case (st)
                ST_IDLE: begin
                    if (rx_udp_hdr_valid && rx_udp_hdr_ready) begin
                        st <= match_port ? ST_ECHO : ST_DROP;
                    end
                end
                ST_ECHO: begin
                    if (rx_udp_payload_axis_tvalid && rx_udp_payload_axis_tready && rx_udp_payload_axis_tlast) begin
                        st <= ST_IDLE;
                    end
                end
                ST_DROP: begin
                    if (rx_udp_payload_axis_tvalid && rx_udp_payload_axis_tready && rx_udp_payload_axis_tlast) begin
                        st <= ST_IDLE;
                    end
                end
                default: st <= ST_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // LEDs: [2]=heartbeat, [1]=tx activity, [0]=rx activity
    // ------------------------------------------------------------------------
    logic [23:0] act_cnt_rx = '0;
    logic [23:0] act_cnt_tx = '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            act_cnt_rx <= '0;
            act_cnt_tx <= '0;
        end else begin
            // pulse-stretch ~0.2s @ 50MHz => 10M cycles (~24 bits)
            if (rx_udp_hdr_valid && rx_udp_hdr_ready) act_cnt_rx <= 24'd10_000_000;
            else if (act_cnt_rx != 0) act_cnt_rx <= act_cnt_rx - 1'b1;

            if (tx_udp_hdr_valid && tx_udp_hdr_ready) act_cnt_tx <= 24'd10_000_000;
            else if (act_cnt_tx != 0) act_cnt_tx <= act_cnt_tx - 1'b1;
        end
    end

    //assign eth_led[2] = hb_led;
    //assign eth_led[1] = (act_cnt_tx != 0);
    //assign eth_led[0] = (act_cnt_rx != 0);
    ///////////////////////////////////////////
    assign eth_led[2] = hb_led;
    assign eth_led[1] = link_up;          // LINK indicator from BMSR
    assign eth_led[0] = (act_cnt_rx != 0) | (act_cnt_tx != 0);
    ///////////////////////////////////////////

endmodule
