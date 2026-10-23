// rptr_handler.sv
// Read pointer generation and empty flag logic.

module rptr_handler #(
    parameter int PTR_WIDTH = 3
)(
    input  logic                 rclk,
    input  logic                 rrst_n,
    input  logic                 r_en,
    input  logic [PTR_WIDTH:0]   g_wptr_sync,
    output logic [PTR_WIDTH:0]   b_rptr,
    output logic [PTR_WIDTH:0]   g_rptr,
    output logic                 empty
);

    logic [PTR_WIDTH:0] b_rptr_next;
    logic [PTR_WIDTH:0] g_rptr_next;
    logic               empty_next;

    assign b_rptr_next = b_rptr + (r_en && !empty);
    assign g_rptr_next = (b_rptr_next >> 1) ^ b_rptr_next;
    assign empty_next  = (g_wptr_sync == g_rptr_next);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            b_rptr <= '0;
            g_rptr <= '0;
            empty  <= 1'b1;
        end else begin
            b_rptr <= b_rptr_next;
            g_rptr <= g_rptr_next;
            empty  <= empty_next;
        end
    end

endmodule
