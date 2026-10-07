`timescale 1ns / 1ps

// ============================================================
// Generic testbench for parameterized synchronous FIFO
// ============================================================

module sync_fifo_test #(
    parameter DATA_WIDTH = 8,
    parameter REGS       = 8
);

    logic clk;
    logic rst;

    logic [DATA_WIDTH-1:0] data_in;
    logic wr_en;
    logic rd_en;

    logic [DATA_WIDTH-1:0] data_out;
    logic full;
    logic empty;

    integer i;
    localparam integer HALF_REGS = REGS / 2;


    // ========================================================
    // DUT
    // ========================================================

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .REGS(REGS)
    ) dut (
        .clk(clk),
        .rst(rst),

        .data_in(data_in),
        .wr_en(wr_en),
        .rd_en(rd_en),

        .data_out(data_out),
        .full(full),
        .empty(empty)
    );


    // ========================================================
    // CLOCK
    // ========================================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // ========================================================
    // TEST
    // ========================================================

    initial begin

        // Initial values
        rst     = 0;
        data_in = '0;
        wr_en   = 0;
        rd_en   = 0;

        #2;

        $display("");
        $display("================================================");
        $display("        %0dx%0d SYNCHRONOUS FIFO TEST", DATA_WIDTH, REGS);
        $display("================================================");


        // ----------------------------------------------------
        // RESET TEST
        // ----------------------------------------------------

        rst = 1;
        @(posedge clk);
        #1;
        rst = 0;

        if (!empty || full || data_out !== '0)
            $fatal(1, "%0dx%0d RESET TEST FAILED", DATA_WIDTH, REGS);

        $display("");
        $display("RESET TEST PASSED");
        $display("empty = %0b, full = %0b, data_out = %0h", empty, full, data_out);


        // ----------------------------------------------------
        // EMPTY FIFO TEST
        // ----------------------------------------------------

        rd_en = 1;
        @(posedge clk);
        #1;
        rd_en = 0;

        if (!empty || data_out !== '0)
            $fatal(1, "%0dx%0d EMPTY FIFO TEST FAILED", DATA_WIDTH, REGS);

        $display("");
        $display("EMPTY FIFO TEST PASSED");


        // ----------------------------------------------------
        // WRITE AND FULL TEST
        // ----------------------------------------------------

        for (i = 0; i < REGS; i = i + 1) begin
            data_in = i + 1;
            wr_en   = 1;
            @(posedge clk);
            #1;
        end
        wr_en = 0;

        if (!full || empty)
            $fatal(1, "%0dx%0d FULL TEST FAILED", DATA_WIDTH, REGS);

        // A write while full must be ignored.
        data_in = 'hF;
        wr_en   = 1;
        @(posedge clk);
        #1;
        wr_en = 0;

        if (!full)
            $fatal(1, "%0dx%0d WRITE WHILE FULL TEST FAILED", DATA_WIDTH, REGS);

        $display("");
        $display("WRITE AND FULL TEST PASSED");
        $display("full = %0b", full);


        // ----------------------------------------------------
        // READ AND FIFO ORDER TEST
        // ----------------------------------------------------

        for (i = 0; i < REGS; i = i + 1) begin
            rd_en = 1;
            @(posedge clk);
            #1;

            if (data_out !== (i + 1))
                $fatal(1, "%0dx%0d READ TEST FAILED: expected %0h, got %0h",
                       DATA_WIDTH, REGS, i + 1, data_out);
        end
        rd_en = 0;

        if (!empty || full)
            $fatal(1, "%0dx%0d EMPTY AFTER READ TEST FAILED", DATA_WIDTH, REGS);

        $display("");
        $display("READ AND FIFO ORDER TEST PASSED");


        // ----------------------------------------------------
        // WRAPAROUND TEST
        // ----------------------------------------------------

        // Fill the FIFO, then read half of it.
        for (i = 0; i < REGS; i = i + 1) begin
            data_in = i + 1;
            wr_en   = 1;
            @(posedge clk);
            #1;
        end
        wr_en = 0;

        for (i = 0; i < HALF_REGS; i = i + 1) begin
            rd_en = 1;
            @(posedge clk);
            #1;

            if (data_out !== (i + 1))
                $fatal(1, "%0dx%0d WRAPAROUND READ FAILED", DATA_WIDTH, REGS);
        end
        rd_en = 0;

        // These writes reuse locations at the beginning of memory.
        for (i = 0; i < HALF_REGS; i = i + 1) begin
            data_in = REGS + i + 1;
            wr_en   = 1;
            @(posedge clk);
            #1;
        end
        wr_en = 0;

        if (!full)
            $fatal(1, "%0dx%0d WRAPAROUND FULL TEST FAILED", DATA_WIDTH, REGS);

        // Read the old entries first, then the wrapped entries.
        for (i = HALF_REGS; i < REGS; i = i + 1) begin
            rd_en = 1;
            @(posedge clk);
            #1;

            if (data_out !== (i + 1))
                $fatal(1, "%0dx%0d WRAPAROUND OLD DATA FAILED", DATA_WIDTH, REGS);
        end

        for (i = 0; i < HALF_REGS; i = i + 1) begin
            rd_en = 1;
            @(posedge clk);
            #1;

            if (data_out !== (REGS + i + 1))
                $fatal(1, "%0dx%0d WRAPAROUND NEW DATA FAILED", DATA_WIDTH, REGS);
        end
        rd_en = 0;

        if (!empty)
            $fatal(1, "%0dx%0d WRAPAROUND EMPTY TEST FAILED", DATA_WIDTH, REGS);

        $display("");
        $display("WRAPAROUND TEST PASSED");


        // ----------------------------------------------------
        // SIMULTANEOUS READ / WRITE TEST
        // ----------------------------------------------------

        // Put two entries in the FIFO.
        data_in = 'h3;
        wr_en   = 1;
        @(posedge clk);
        #1;

        data_in = 'h4;
        @(posedge clk);
        #1;
        wr_en = 0;

        // Read the first entry while writing a third entry.
        data_in = 'h5;
        wr_en   = 1;
        rd_en   = 1;
        @(posedge clk);
        #1;
        wr_en = 0;
        rd_en = 0;

        if (data_out !== 'h3 || empty || full)
            $fatal(1, "%0dx%0d SIMULTANEOUS READ/WRITE TEST FAILED", DATA_WIDTH, REGS);

        // The remaining FIFO order must be 4, then 5.
        rd_en = 1;
        @(posedge clk);
        #1;
        if (data_out !== 'h4)
            $fatal(1, "%0dx%0d SIMULTANEOUS ORDER TEST FAILED", DATA_WIDTH, REGS);

        @(posedge clk);
        #1;
        rd_en = 0;
        if (data_out !== 'h5 || !empty)
            $fatal(1, "%0dx%0d SIMULTANEOUS EMPTY TEST FAILED", DATA_WIDTH, REGS);

        $display("");
        $display("SIMULTANEOUS READ / WRITE TEST PASSED");


        // ----------------------------------------------------
        // FINAL RESULT
        // ----------------------------------------------------

        $display("");
        $display("================================================");
        $display("        %0dx%0d TEST COMPLETED", DATA_WIDTH, REGS);
        $display("================================================");
        $display("");

    end

endmodule


module tb_sync_fifo;

    // --------------------------------------------------------
    // VCD
    // --------------------------------------------------------

    initial begin
        $dumpfile("sync_fifo_all.vcd");
        $dumpvars(0, tb_sync_fifo);
    end


    // --------------------------------------------------------
    // 8 x 8
    // --------------------------------------------------------

    sync_fifo_test #(
        .DATA_WIDTH(8),
        .REGS(8)
    ) test_8x8();


    // --------------------------------------------------------
    // 16 x 16
    // --------------------------------------------------------

    sync_fifo_test #(
        .DATA_WIDTH(16),
        .REGS(16)
    ) test_16x16();


    // --------------------------------------------------------
    // 4 x 4
    // --------------------------------------------------------

    sync_fifo_test #(
        .DATA_WIDTH(4),
        .REGS(4)
    ) test_4x4();


    // Keep simulation alive until all tests finish
    initial begin
        #2000;
        $finish;
    end

endmodule
