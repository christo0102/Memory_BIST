`timescale 1ns / 1ps

// 64x8 synchronous RAM with a TEST-ONLY fault-injection model.
// fault_en = 0  -> ideal, healthy RAM
// fault_en = 1  -> one faulty cell (fault_addr, fault_bit) of type fault_type
//
// fault_type: 0 = Stuck-At-0   1 = Stuck-At-1
//             2 = Transition fault, rise (0->1 fails)
//             3 = Transition fault, fall (1->0 fails)
module ram_64x8 #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6
)(
    input  wire                  clk,
    input  wire                  ram_we,
    input  wire [ADDR_WIDTH-1:0] ram_addr,
    input  wire [DATA_WIDTH-1:0] ram_din,
    output reg  [DATA_WIDTH-1:0] ram_dout,

    // fault-injection controls (tie to 0 for a healthy RAM)
    input  wire                  fault_en,
    input  wire [ADDR_WIDTH-1:0] fault_addr,
    input  wire [2:0]            fault_bit,
    input  wire [1:0]            fault_type
);
    localparam SA0 = 2'd0, SA1 = 2'd1, TF_RISE = 2'd2, TF_FALL = 2'd3;

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    reg [DATA_WIDTH-1:0] rd_word, wr_word;
    integer i;

    initial for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) mem[i] = {DATA_WIDTH{1'b0}};

    wire hit = fault_en && (ram_addr == fault_addr);

    always @(posedge clk) begin
        // ---- read path (old data, synchronous output) ----
        rd_word = mem[ram_addr];
        if (hit) begin
            if (fault_type == SA0) rd_word[fault_bit] = 1'b0;
            if (fault_type == SA1) rd_word[fault_bit] = 1'b1;
        end
        ram_dout <= rd_word;

        // ---- write path: fault is stored in the cell, so it persists ----
        if (ram_we) begin
            wr_word = ram_din;
            if (hit) begin
                case (fault_type)
                    SA0:     wr_word[fault_bit] = 1'b0;
                    SA1:     wr_word[fault_bit] = 1'b1;
                    TF_RISE: wr_word[fault_bit] = mem[ram_addr][fault_bit] & ram_din[fault_bit];
                    TF_FALL: wr_word[fault_bit] = mem[ram_addr][fault_bit] | ram_din[fault_bit];
                endcase
            end
            mem[ram_addr] <= wr_word;
        end
    end
endmodule
