`timescale 1ns / 1ps

module module_top_tb;

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 6;
    reg                    clk;
    reg                    rst;
    reg                    sys_we;
    reg                    test_mode;
    reg  [ADDR_WIDTH-1:0]  sys_addr;
    reg  [DATA_WIDTH-1:0]  sys_din;
    
    wire [DATA_WIDTH-1:0]  ram_dout;
    wire                   bist_finish;
    wire                   bist_fail;
    wire [ADDR_WIDTH-1:0]  fail_addr;
    wire [DATA_WIDTH-1:0]  actual_data;
    wire [DATA_WIDTH-1:0]  expected_data; 

    // Instantiate the Top-Level 
    module_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .sys_we(sys_we),
        .test_mode(test_mode),
        .sys_addr(sys_addr),
        .sys_din(sys_din),
        .ram_dout(ram_dout),
        .bist_finish(bist_finish),
        .bist_fail(bist_fail),
        .fail_addr(fail_addr),
        .actual_data(actual_data),
        .expected_data(expected_data)
    );

   
    always #10 clk = ~clk;
    
    initial begin
        clk       = 1'b0;
        rst       = 1'b1;
        test_mode = 1'b0;
        sys_we    = 1'b0;
        sys_addr  = {ADDR_WIDTH{1'b0}};
        sys_din   = {DATA_WIDTH{1'b0}};
        #40;
        rst = 1'b0;
        #20;
        
        // ----------------------------------------------------
        // RUN 1: Clean Pass Test 
        // ----------------------------------------------------
        $display("[TB] ----- starting clean run (healthy ram) -----");
        test_mode = 1'b1; 

        @(posedge bist_finish);
        #10; 
        
        if (bist_fail == 1'b0) begin
            $display("[TB] SUCCESS: Clean run completed! No faults flagged.");
        end else begin
            $display("[TB] ERROR: Clean run reported false failure at Address: %d", fail_addr);
        end
        
        test_mode = 1'b0; 
        #40;

        // ----------------------------------------------------
        // RUN 2: Multi-Fault Detection Test
        // ----------------------------------------------------
        $display("[TB] ----- starting error run (multi-fault ram) -----");
        rst = 1'b1;
        #40;
        rst = 1'b0;
        #20;

        test_mode = 1'b1; 
        wait(uut.wrapper.mbist.state == 4'd2); 
        
        uut.wrapper.U_RAM.mem[10] = 8'hFF;
        uut.wrapper.U_RAM.mem[25] = 8'h00;
        uut.wrapper.U_RAM.mem[40] = 8'h55; 
        
        $display("[TB] Injected Stuck-At-1 at Addr 10, Stuck-At-0 at Addr 25, Pattern at Addr 40.");

        @(posedge bist_finish or posedge bist_fail);
        #10;
        
        if (bist_fail == 1'b1) begin
            $display("[TB] SUCCESS: BIST flagged an error!");
            $display("[TB] First Fault Encountered at Address: %d", fail_addr);
            $display("[TB] Actual Data Read:                   0x%h", actual_data);
            $display("[TB] Expected Data:                      0x%h", expected_data);
        end else begin
            $display("[TB] ERROR: BIST completely missed all injected faults!");
        end

        #100;
        $display("[TB] Simulation Completed.");
        $finish;
    end

endmodule
