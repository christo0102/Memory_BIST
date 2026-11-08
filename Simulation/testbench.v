`timescale 1ns / 1ps

module module_top_tb;

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 6;

    reg                    clk, rst, sys_we, test_mode;
    reg  [ADDR_WIDTH-1:0]  sys_addr;
    reg  [DATA_WIDTH-1:0]  sys_din;
    reg                    fault_en;
    reg  [ADDR_WIDTH-1:0]  fault_addr_in;
    reg  [2:0]             fault_bit;
    reg  [1:0]             fault_type;

    wire [DATA_WIDTH-1:0]  ram_dout;
    wire                   bist_finish, bist_fail;
    wire [ADDR_WIDTH-1:0]  fail_addr;
    wire [DATA_WIDTH-1:0]  actual_data;

    module_top #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) uut (
        .clk(clk), .rst(rst), .sys_we(sys_we), .test_mode(test_mode),
        .sys_addr(sys_addr), .sys_din(sys_din), .ram_dout(ram_dout),
        .bist_finish(bist_finish), .bist_fail(bist_fail),
        .fail_addr(fail_addr), .actual_data(actual_data),
        .fault_en(fault_en), .fault_addr_in(fault_addr_in),
        .fault_bit(fault_bit), .fault_type(fault_type)
    );

    // 50 MHz clock
    initial clk = 1'b0;
    always #10 clk = ~clk;

    integer total, passed;

    // fault type names for printing
    function [95:0] tname(input [1:0] t);
        case (t)
            2'd0: tname = "SA0        ";
            2'd1: tname = "SA1        ";
            2'd2: tname = "TF rise 0>1";
            2'd3: tname = "TF fall 1>0";
        endcase
    endfunction

    // Run one full BIST pass. inject=0 -> healthy RAM.
    task run_bist(input inject, input [1:0] ftype,
                  input [ADDR_WIDTH-1:0] faddr, input [2:0] fbit);
        reg done;
        begin
            // reset controller, then configure fault
            test_mode = 1'b0;
            rst = 1'b1;  #40;  rst = 1'b0;  #20;
            fault_en      = inject;
            fault_type    = ftype;
            fault_addr_in = faddr;
            fault_bit     = fbit;

            test_mode = 1'b1;
            done = 1'b0;
            fork : wait_blk
                begin @(posedge bist_finish); done = 1'b1; disable wait_blk; end
                begin #200000;                               disable wait_blk; end
            join
            #1;
            test_mode = 1'b0;     // drop before DONE -> IDLE restarts the test
            #40;

            total = total + 1;
            if (!done) begin
                $display("[TB] FAIL  : timeout, BIST never finished");
            end else if (!inject) begin
                if (!bist_fail) begin
                    passed = passed + 1;
                    $display("[TB] PASS  : healthy RAM, no fault flagged");
                end else
                    $display("[TB] FAIL  : false failure at addr %0d", fail_addr);
            end else begin
                if (bist_fail && fail_addr == faddr) begin
                    passed = passed + 1;
                    $display("[TB] PASS  : %s addr=%2d bit=%0d -> detected, fail_addr=%2d, data read=0x%02h",
                             tname(ftype), faddr, fbit, fail_addr, actual_data);
                end else if (bist_fail)
                    $display("[TB] FAIL  : %s addr=%2d bit=%0d -> wrong fail_addr=%0d",
                             tname(ftype), faddr, fbit, fail_addr);
                else
                    $display("[TB] FAIL  : %s addr=%2d bit=%0d -> MISSED", tname(ftype), faddr, fbit);
            end
        end
    endtask

    integer t;
    initial begin
        total = 0; passed = 0;
        rst = 1'b1; test_mode = 1'b0; sys_we = 1'b0;
        sys_addr = 0; sys_din = 0;
        fault_en = 0; fault_addr_in = 0; fault_bit = 0; fault_type = 0;
        #40;

        $display("[TB] ===== Healthy RAM =====");
        run_bist(1'b0, 2'd0, 6'd0, 3'd0);

        $display("[TB] ===== Injected faults (every type, corner + middle addresses) =====");
        for (t = 0; t < 4; t = t + 1) begin
            run_bist(1'b1, t[1:0], 6'd0,  3'd0);
            run_bist(1'b1, t[1:0], 6'd32, 3'd3);
            run_bist(1'b1, t[1:0], 6'd63, 3'd7);
        end

        $display("[TB] =====================================");
        $display("[TB] RESULT: %0d / %0d runs passed", passed, total);
        if (passed == total) $display("[TB] ALL TESTS PASSED");
        else                 $display("[TB] SOME TESTS FAILED");
        $finish;
    end

endmodule
