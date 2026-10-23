// tb_async_fifo_resume.sv
// Resume-worthy self-checking SystemVerilog testbench for Asynchronous FIFO.
// Features: asynchronous clocks, directed tests, random stress test, scoreboard,
// assertions, simple functional coverage counters, and VCD dump.

`timescale 1ns/1ps

module tb_async_fifo_resume;

    parameter int DEPTH      = 8;
    parameter int DATA_WIDTH = 8;
    parameter int PTR_WIDTH  = $clog2(DEPTH);
    parameter int SB_SIZE    = 4096;

    logic                  wclk;
    logic                  rclk;
    logic                  wrst_n;
    logic                  rrst_n;
    logic                  w_en;
    logic                  r_en;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic                  full;
    logic                  empty;

    int unsigned pass_count;
    int unsigned fail_count;
    int unsigned write_count;
    int unsigned read_count;
    int unsigned full_seen;
    int unsigned empty_seen;
    int unsigned simultaneous_seen;
    int unsigned blocked_write_seen;
    int unsigned blocked_read_seen;

    logic [DATA_WIDTH-1:0] expected_mem [0:SB_SIZE-1];
    int unsigned exp_wr_idx;
    int unsigned exp_rd_idx;

    asynchronous_fifo #(
        .DEPTH      (DEPTH),
        .DATA_WIDTH (DATA_WIDTH),
        .PTR_WIDTH  (PTR_WIDTH)
    ) dut (
        .wclk     (wclk),
        .wrst_n   (wrst_n),
        .rclk     (rclk),
        .rrst_n   (rrst_n),
        .w_en     (w_en),
        .r_en     (r_en),
        .data_in  (data_in),
        .data_out (data_out),
        .full     (full),
        .empty    (empty)
    );

    // Asynchronous clocks: different periods to verify CDC behavior.
    initial wclk = 1'b0;
    initial rclk = 1'b0;
    always #5   wclk = ~wclk;   // 100 MHz write clock
    always #7.5 rclk = ~rclk;   // ~66.7 MHz read clock

    initial begin
        $dumpfile("async_fifo_resume.vcd");
        $dumpvars(0, tb_async_fifo_resume);
    end

    task automatic report_pass(input string msg);
        pass_count++;
        $display("[PASS] %0t : %s", $time, msg);
    endtask

    task automatic report_fail(input string msg);
        fail_count++;
        $error("[FAIL] %0t : %s", $time, msg);
    endtask

    task automatic apply_reset();
        w_en      = 1'b0;
        r_en      = 1'b0;
        data_in   = '0;
        wrst_n    = 1'b0;
        rrst_n    = 1'b0;
        exp_wr_idx = 0;
        exp_rd_idx = 0;
        repeat (5) @(posedge wclk);
        repeat (3) @(posedge rclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;
        repeat (4) @(posedge wclk);
        repeat (4) @(posedge rclk);
    endtask

    task automatic write_one(input logic [DATA_WIDTH-1:0] din);
        @(negedge wclk);
        data_in = din;
        w_en    = 1'b1;
        @(negedge wclk);
        w_en    = 1'b0;
    endtask

    task automatic read_one();
        @(negedge rclk);
        r_en = 1'b1;
        @(negedge rclk);
        r_en = 1'b0;
    endtask

    task automatic wait_write_clocks(input int n);
        repeat (n) @(posedge wclk);
    endtask

    task automatic wait_read_clocks(input int n);
        repeat (n) @(posedge rclk);
    endtask

    // Write monitor: update scoreboard only when DUT actually accepts write.
    always @(posedge wclk) begin
        if (!wrst_n) begin
            write_count <= 0;
        end else begin
            if (full) full_seen <= full_seen + 1;

            if (w_en && !full) begin
                expected_mem[exp_wr_idx % SB_SIZE] = data_in;
                exp_wr_idx++;
                write_count++;
            end

            if (w_en && full) begin
                blocked_write_seen <= blocked_write_seen + 1;
            end
        end
    end

    // Read monitor: compare output against scoreboard after registered read update.
    always @(posedge rclk) begin
        if (!rrst_n) begin
            read_count <= 0;
        end else begin
            if (empty) empty_seen <= empty_seen + 1;

            if (r_en && !empty) begin
                logic [DATA_WIDTH-1:0] exp_data;
                exp_data = expected_mem[exp_rd_idx % SB_SIZE];
                #1;
                if (data_out === exp_data) begin
                    pass_count++;
                end else begin
                    fail_count++;
                    $error("[DATA MISMATCH] %0t : expected=%0h actual=%0h read_index=%0d",
                           $time, exp_data, data_out, exp_rd_idx);
                end
                exp_rd_idx++;
                read_count++;
            end

            if (r_en && empty) begin
                blocked_read_seen <= blocked_read_seen + 1;
            end
        end
    end

    // Simple protocol assertions.
    always @(posedge wclk) begin
        if (wrst_n) begin
            assert (!(w_en && full && (dut.u_wptr_handler.b_wptr_next != dut.u_wptr_handler.b_wptr)))
                else report_fail("Write pointer changed during full condition");
        end
    end

    always @(posedge rclk) begin
        if (rrst_n) begin
            assert (!(r_en && empty && (dut.u_rptr_handler.b_rptr_next != dut.u_rptr_handler.b_rptr)))
                else report_fail("Read pointer changed during empty condition");
        end
    end

    task automatic directed_tests();
        $display("\n--- Directed Tests Started ---");

        if (empty === 1'b1) report_pass("FIFO empty after reset");
        else                report_fail("FIFO not empty after reset");

        // Empty read test: read should be blocked.
        read_one();
        wait_read_clocks(2);

        // Fill FIFO completely.
        for (int i = 0; i < DEPTH; i++) begin
            write_one(8'hA0 + i[7:0]);
        end
        wait_write_clocks(4); // allow full flag to settle in write clock domain

        if (full === 1'b1) report_pass("Full flag asserted after DEPTH writes");
        else               report_fail("Full flag not asserted after DEPTH writes");

        // Extra write must be blocked when full.
        write_one(8'hFF);
        wait_write_clocks(2);

        // Drain FIFO completely.
        for (int i = 0; i < DEPTH; i++) begin
            read_one();
        end
        wait_read_clocks(4); // allow empty flag to settle in read clock domain

        if (empty === 1'b1) report_pass("Empty flag asserted after all reads");
        else                report_fail("Empty flag not asserted after all reads");

        $display("--- Directed Tests Completed ---\n");
    endtask

    task automatic random_stress_test(input int cycles);
        $display("\n--- Random Stress Test Started: %0d cycles ---", cycles);

        fork
            begin : WRITE_STIM
                for (int i = 0; i < cycles; i++) begin
                    @(negedge wclk);
                    w_en    = $urandom_range(0, 1);
                    data_in = $urandom_range(0, 255);
                end
                @(negedge wclk);
                w_en = 1'b0;
            end

            begin : READ_STIM
                for (int i = 0; i < cycles; i++) begin
                    @(negedge rclk);
                    r_en = $urandom_range(0, 1);
                end
                @(negedge rclk);
                r_en = 1'b0;
            end

            begin : SIMUL_COV
                for (int i = 0; i < cycles; i++) begin
                    @(posedge wclk);
                    if (w_en && r_en) simultaneous_seen++;
                end
            end
        join

        // Drain any remaining data.
        repeat (DEPTH + 8) begin
            if (!empty) read_one();
            else       wait_read_clocks(1);
        end

        wait_read_clocks(5);
        $display("--- Random Stress Test Completed ---\n");
    endtask

    initial begin
        pass_count          = 0;
        fail_count          = 0;
        write_count         = 0;
        read_count          = 0;
        full_seen           = 0;
        empty_seen          = 0;
        simultaneous_seen   = 0;
        blocked_write_seen  = 0;
        blocked_read_seen   = 0;

        apply_reset();
        directed_tests();
        random_stress_test(300);

        $display("\n================ FIFO VERIFICATION SUMMARY ================");
        $display("Accepted writes       : %0d", write_count);
        $display("Successful reads      : %0d", read_count);
        $display("Full flag seen        : %0d", full_seen);
        $display("Empty flag seen       : %0d", empty_seen);
        $display("Simultaneous activity : %0d", simultaneous_seen);
        $display("Blocked writes        : %0d", blocked_write_seen);
        $display("Blocked reads         : %0d", blocked_read_seen);
        $display("Pass count            : %0d", pass_count);
        $display("Fail count            : %0d", fail_count);
        $display("===========================================================\n");

        if (fail_count == 0) begin
            $display("TEST RESULT: PASS");
        end else begin
            $display("TEST RESULT: FAIL");
        end

        $finish;
    end

endmodule
