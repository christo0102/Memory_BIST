`timescale 1ns / 1ps

module ram_64x8 #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6
)(
    input  wire                  clk,
    input  wire                  ram_we,
    input  wire [ADDR_WIDTH-1:0] ram_addr,
    input  wire [DATA_WIDTH-1:0] ram_din,
    output reg  [DATA_WIDTH-1:0] ram_dout
);
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    
    always @(posedge clk) begin
        if(ram_we) begin
            mem[ram_addr] <= ram_din;  
        end
        ram_dout <= mem[ram_addr]; 
    end
endmodule
