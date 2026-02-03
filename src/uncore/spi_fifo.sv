module spi_fifo #(
    parameter int M = 3,   // log2(depth)
    parameter int N = 8
)(
    input  logic         PCLK, wen, ren, PRESETn,
    input  logic         winc, rinc,
    input  logic [N-1:0] wdata,
    input  logic [M-1:0] wwatermarklevel, rwatermarklevel,
    output logic [N-1:0] rdata,
    output logic         wfull, rempty,
    output logic         wwatermark, rwatermark
);

    localparam int DEPTH = (1 << M);

    logic [N-1:0] mem [DEPTH];

    logic [M:0] wptr, rptr;
    logic [M:0] wptr_next, rptr_next;
    logic       wdo, rdo;

    logic [M:0] level_next;
    logic       wfull_next, rempty_next;

    // qualified increments
    assign wdo = wen & winc & ~wfull;
    assign rdo = ren & rinc & ~rempty;

    // next pointers
    assign wptr_next = wptr + {{M{1'b0}}, wdo};
    assign rptr_next = rptr + {{M{1'b0}}, rdo};

    // true occupancy after updates (0..DEPTH)
    assign level_next = wptr_next - rptr_next;

    // full/empty after updates (binary ring)
    assign wfull_next  = ({~wptr_next[M], wptr_next[M-1:0]} == rptr_next);
    assign rempty_next = (wptr_next == rptr_next);

    // memory
    assign rdata = mem[rptr[M-1:0]];
    always_ff @(posedge PCLK) begin
        if (wdo) mem[wptr[M-1:0]] <= wdata;
    end

    // registers
    always_ff @(posedge PCLK) begin
        if (!PRESETn) begin
            wptr   <= '0;
            rptr   <= '0;
            wfull  <= 1'b0;
            rempty <= 1'b1;
        end else begin
            wptr   <= wptr_next;
            rptr   <= rptr_next;
            wfull  <= wfull_next;
            rempty <= rempty_next;
        end
    end

    // watermark conditions (SiFive style)
    // txwm: entries strictly less than txmark
    // rxwm: entries strictly greater than rxmark
    assign rwatermark = (level_next < {1'b0, rwatermarklevel}) & ~wfull_next;
    assign wwatermark = (level_next > {1'b0, wwatermarklevel}) |  wfull_next;

endmodule

