`timescale 1ns / 1ps

module ram_mbist_wrapper #(
    parameter DATA_WIDTH = 8, 
    parameter ADDR_WIDTH = 6
)(
    input  wire                    clk,
    input  wire                    sys_we,
    input  wire [ADDR_WIDTH-1:0]   sys_addr,
    input  wire [DATA_WIDTH-1:0]   sys_din,
    output wire [DATA_WIDTH-1:0]   ram_dout,
    input  wire                    rst,
    input  wire                    test_mode,
    output wire                    bist_finish,
    output wire                    bist_fail,
    output wire [ADDR_WIDTH-1:0]   fail_addr,
    output wire [DATA_WIDTH-1:0]   actual_data,
    output wire [DATA_WIDTH-1:0]   expected_data
);

    wire                    bist_we;
    wire [ADDR_WIDTH-1:0]   bist_addr;
    wire [DATA_WIDTH-1:0]   bist_din;
    wire                    ram_we;
    wire [ADDR_WIDTH-1:0]   ram_addr;
    wire [DATA_WIDTH-1:0]   ram_din;

    assign ram_we   = (test_mode) ? bist_we   : sys_we;
    assign ram_addr = (test_mode) ? bist_addr : sys_addr;
    assign ram_din  = (test_mode) ? bist_din  : sys_din;

    ram_64x8 #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_RAM (
        .clk(clk),
        .ram_we(ram_we),
        .ram_addr(ram_addr),
        .ram_din(ram_din),
        .ram_dout(ram_dout)
    );

    mbist_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) mbist (
        .clk(clk),
        .rst(rst),
        .test_mode(test_mode),
        .ram_dout(ram_dout),
        .bist_din(bist_din),
        .bist_we(bist_we),
        .bist_addr(bist_addr),
        .bist_finish(bist_finish),
        .bist_fail(bist_fail),
        .fail_addr(fail_addr),
        .actual_data(actual_data),
        .expected_data(expected_data)
    );  
endmodule
