// wptr_handler.sv
// Write pointer generation and full flag logic.

module wptr_handler #(
    parameter int PTR_WIDTH = 3
)(
    input  logic                 wclk,
    input  logic                 wrst_n,
    input  logic                 w_en,
    input  logic [PTR_WIDTH:0]   g_rptr_sync,
    output logic [PTR_WIDTH:0]   b_wptr,
    output logic [PTR_WIDTH:0]   g_wptr,
    output logic                 full
);

    logic [PTR_WIDTH:0] b_wptr_next;
    logic [PTR_WIDTH:0] g_wptr_next;
    logic               full_next;

    assign b_wptr_next = b_wptr + (w_en && !full);
    assign g_wptr_next = (b_wptr_next >> 1) ^ b_wptr_next;

    // FIFO is full when next write Gray pointer equals synchronized read pointer
    // with the two MSBs inverted.
    assign full_next = (g_wptr_next == {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1],
                                         g_rptr_sync[PTR_WIDTH-2:0]});

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            b_wptr <= '0;
            g_wptr <= '0;
            full   <= 1'b0;
        end else begin
            b_wptr <= b_wptr_next;
            g_wptr <= g_wptr_next;
            full   <= full_next;
        end
    end

endmodule
