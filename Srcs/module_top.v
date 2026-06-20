`timescale 1ns / 1ps

module module_top #(
    parameter DATA_WIDTH = 8, 
    parameter ADDR_WIDTH = 6
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    sys_we,
    input  wire                    test_mode,
    input  wire [ADDR_WIDTH-1:0]   sys_addr,
    input  wire [DATA_WIDTH-1:0]   sys_din,
    output wire [DATA_WIDTH-1:0]   ram_dout,
    output wire                    bist_finish,
    output wire                    bist_fail,
    output wire [ADDR_WIDTH-1:0]   fail_addr,
    output wire [DATA_WIDTH-1:0]   actual_data,
    output wire [DATA_WIDTH-1:0]   expected_data 
);
    
    ram_mbist_wrapper #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) wrapper (
        .clk(clk),
        .rst(rst),
        .sys_we(sys_we),
        .test_mode(test_mode),
        .sys_din(sys_din),
        .sys_addr(sys_addr),
        .ram_dout(ram_dout),
        .bist_fail(bist_fail),
        .bist_finish(bist_finish),
        .fail_addr(fail_addr),
        .actual_data(actual_data),
        .expected_data(expected_data)
    );
endmodule
