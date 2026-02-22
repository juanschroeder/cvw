module spi_fifo #(parameter M=3, N=8)(                 // 2^M entries of N bits each
    input  logic         PCLK, wen, ren, PRESETn,
    input  logic         winc, rinc,
    input  logic [N-1:0] wdata,
    input  logic [M-1:0] wwatermarklevel, rwatermarklevel,
    output logic [N-1:0] rdata,
    output logic         wfull, rempty,
    output logic         wwatermark, rwatermark);

    /* Pointer FIFO using design elements from "Simulation and Synthesis Techniques
       for Asynchronous FIFO Design" by Clifford E. Cummings. Namely, M bit read and write pointers
       are an extra bit larger than address size to determine full/empty conditions.
       Watermark comparisons use 2's complement subtraction between the M-1 bit pointers,
       which are also used to address memory
    */

    logic [N-1:0] mem[2**M];
    logic [M:0] rptr, wptr;
    logic [M:0] rptrnext, wptrnext;
    logic       wdo, rdo;

    logic [M:0] levelnext;
    logic       wfullnext, remptynext;

    // qualified increments
    assign wdo = wen & winc & ~wfull;
    assign rdo = ren & rinc & ~rempty;

    // next pointers
    assign wptrnext = wptr + {{M{1'b0}}, wdo};
    assign rptrnext = rptr + {{M{1'b0}}, rdo};

    // true occupancy after updates
    assign levelnext = wptrnext - rptrnext;

    // full/empty after updates (binary ring)
    assign wfullnext  = ({~wptrnext[M], wptrnext[M-1:0]} == rptrnext);
    assign remptynext = (wptrnext == rptrnext);

    // memory
    assign rdata = mem[rptr[M-1:0]];
    always_ff @(posedge PCLK) begin
        if (wdo) mem[wptr[M-1:0]] <= wdata;
    end

    // registers
    always_ff @(posedge PCLK) begin
        if (!PRESETn) begin
            rptr   <= '0;
            wptr   <= '0;
            wfull  <= 1'b0;
            rempty <= 1'b1;
        end else begin
            wptr   <= wptrnext;
            rptr   <= rptrnext;
            wfull  <= wfullnext;
            rempty <= remptynext;
        end
    end

    // watermark conditions (SiFive style)
    // txwm: entries strictly less than txmark
    // rxwm: entries strictly greater than rxmark
    assign rwatermark = (levelnext < {1'b0, rwatermarklevel}) & ~wfullnext;
    assign wwatermark = (levelnext > {1'b0, wwatermarklevel}) | wfullnext;

endmodule
