// asynchronous_fifo.sv
// Top module for Asynchronous FIFO with CDC-safe Gray pointer synchronization.

module asynchronous_fifo #(
    parameter int DEPTH      = 8,
    parameter int DATA_WIDTH = 8,
    parameter int PTR_WIDTH  = $clog2(DEPTH)
)(
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  w_en,
    input  logic                  r_en,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  full,
    output logic                  empty
);

    logic [PTR_WIDTH:0] b_wptr, b_rptr;
    logic [PTR_WIDTH:0] g_wptr, g_rptr;
    logic [PTR_WIDTH:0] g_wptr_sync, g_rptr_sync;

    synchronizer #(.WIDTH(PTR_WIDTH)) sync_wptr_to_rclk (
        .clk   (rclk),
        .rst_n (rrst_n),
        .d_in  (g_wptr),
        .d_out (g_wptr_sync)
    );

    synchronizer #(.WIDTH(PTR_WIDTH)) sync_rptr_to_wclk (
        .clk   (wclk),
        .rst_n (wrst_n),
        .d_in  (g_rptr),
        .d_out (g_rptr_sync)
    );

    wptr_handler #(.PTR_WIDTH(PTR_WIDTH)) u_wptr_handler (
        .wclk        (wclk),
        .wrst_n      (wrst_n),
        .w_en        (w_en),
        .g_rptr_sync (g_rptr_sync),
        .b_wptr      (b_wptr),
        .g_wptr      (g_wptr),
        .full        (full)
    );

    rptr_handler #(.PTR_WIDTH(PTR_WIDTH)) u_rptr_handler (
        .rclk        (rclk),
        .rrst_n      (rrst_n),
        .r_en        (r_en),
        .g_wptr_sync (g_wptr_sync),
        .b_rptr      (b_rptr),
        .g_rptr      (g_rptr),
        .empty       (empty)
    );

    fifo_mem #(
        .DEPTH      (DEPTH),
        .DATA_WIDTH (DATA_WIDTH),
        .PTR_WIDTH  (PTR_WIDTH)
    ) u_fifo_mem (
        .wclk     (wclk),
        .w_en     (w_en),
        .rclk     (rclk),
        .r_en     (r_en),
        .b_wptr   (b_wptr),
        .b_rptr   (b_rptr),
        .data_in  (data_in),
        .full     (full),
        .empty    (empty),
        .data_out (data_out)
    );

endmodule
