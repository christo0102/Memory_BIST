`timescale 1ns / 1ps

module mbist_controller #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  test_mode,
    input  wire [DATA_WIDTH-1:0] ram_dout,
    output reg  [DATA_WIDTH-1:0] bist_din,
    output reg  [ADDR_WIDTH-1:0] bist_addr,
    output reg                   bist_we,
    output reg                   bist_finish,
    output reg                   bist_fail,
    output reg  [ADDR_WIDTH-1:0] fail_addr,
    output reg  [DATA_WIDTH-1:0] actual_data,
    output reg  [DATA_WIDTH-1:0] expected_data
);

    localparam IDLE          = 4'd0,
               W0_UP         = 4'd1,
               READ0_UP      = 4'd2,
               CMP0_W1_UP    = 4'd3, 
               READ1_UP      = 4'd4,
               CMP1_W0_UP    = 4'd5,
               READ0_DOWN    = 4'd6,
               CMP0_W1_DOWN  = 4'd7,
               READ1_DOWN    = 4'd8,
               CMP1_W0_DOWN  = 4'd9,
               READ0_FINAL   = 4'd10,
               CMP0_FINAL    = 4'd11,
               DONE          = 4'd12;

    reg [3:0] state, next_state;
    reg [ADDR_WIDTH-1:0] addr_delayed;
    reg compare_en;
    reg addr_done;

    // State Register
    always @(posedge clk or posedge rst) begin
        if(rst) state <= IDLE;
        else    state <= next_state;
    end

    // Address Boundary Detection Flag
    always @(*) begin
        addr_done = 1'b0;
        case(state)
            W0_UP:         addr_done = (bist_addr    == 6'd63);
            CMP0_W1_UP:    addr_done = (addr_delayed == 6'd63);
            CMP1_W0_UP:    addr_done = (addr_delayed == 6'd63);
            CMP0_W1_DOWN:  addr_done = (addr_delayed == 6'd0);
            CMP1_W0_DOWN:  addr_done = (addr_delayed == 6'd0);
            CMP0_FINAL:    addr_done = (addr_delayed == 6'd63);
            default:       addr_done = 1'b0;
        endcase
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case(state)
            IDLE:          if(test_mode) next_state = W0_UP;
            W0_UP:         if(addr_done) next_state = READ0_UP;

            READ0_UP:      next_state = CMP0_W1_UP;
            CMP0_W1_UP:    next_state = addr_done ? READ1_UP : READ0_UP;

            READ1_UP:      next_state = CMP1_W0_UP;
            CMP1_W0_UP:    next_state = addr_done ? READ0_DOWN : READ1_UP;

            READ0_DOWN:    next_state = CMP0_W1_DOWN;
            CMP0_W1_DOWN:  next_state = addr_done ? READ1_DOWN : READ0_DOWN;

            READ1_DOWN:    next_state = CMP1_W0_DOWN;
            CMP1_W0_DOWN:  next_state = addr_done ? READ0_FINAL : READ1_DOWN;

            READ0_FINAL:   next_state = CMP0_FINAL;
            CMP0_FINAL:    next_state = addr_done ? DONE : READ0_FINAL;

            DONE:          next_state = IDLE;
            default:       next_state = IDLE;
        endcase
    end

    // Control Output & Expected Data Decoder
    always @(*) begin
        bist_we       = 1'b0;
        bist_din      = {DATA_WIDTH{1'b0}};
        expected_data = {DATA_WIDTH{1'b0}};
        bist_finish   = 1'b0;
        compare_en    = 1'b0;

        case(state)
            W0_UP: begin
                bist_we  = 1'b1;
                bist_din = {DATA_WIDTH{1'b0}};
            end
            CMP0_W1_UP: begin
                bist_we       = 1'b1;
                bist_din      = {DATA_WIDTH{1'b1}}; 
                expected_data = {DATA_WIDTH{1'b0}}; 
                compare_en    = 1'b1;
            end
            CMP1_W0_UP: begin
                bist_we       = 1'b1;
                bist_din      = {DATA_WIDTH{1'b0}}; 
                expected_data = {DATA_WIDTH{1'b1}}; 
                compare_en    = 1'b1;
            end
            CMP0_W1_DOWN: begin
                bist_we       = 1'b1;
                bist_din      = {DATA_WIDTH{1'b1}}; 
                expected_data = {DATA_WIDTH{1'b0}}; 
                compare_en    = 1'b1;
            end
            CMP1_W0_DOWN: begin
                bist_we       = 1'b1;
                bist_din      = {DATA_WIDTH{1'b0}}; 
                expected_data = {DATA_WIDTH{1'b1}}; 
                compare_en    = 1'b1;
            end
            CMP0_FINAL: begin
                expected_data = {DATA_WIDTH{1'b0}};
                compare_en    = 1'b1;
            end
            DONE: begin
                bist_finish = 1'b1;
            end
        endcase
    end

    // Pipeline Address Counter Generation
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            bist_addr    <= 6'd0;
            addr_delayed <= 6'd0;
        end else begin
            if (state != IDLE) begin
                addr_delayed <= bist_addr; 
            end

            case(state)
                IDLE: begin
                    bist_addr    <= 6'd0;
                    addr_delayed <= 6'd0;
                end

                W0_UP: begin
                    if(addr_done) bist_addr <= 6'd0; 
                    else          bist_addr <= bist_addr + 1'b1;
                end

                READ0_UP, READ1_UP, READ0_DOWN, READ1_DOWN, READ0_FINAL: begin
                    bist_addr <= bist_addr; 
                end

                CMP0_W1_UP: begin
                    if(addr_done) bist_addr <= 6'd0; 
                    else          bist_addr <= bist_addr + 1'b1;
                end

                CMP1_W0_UP: begin 
                    if(addr_done) bist_addr <= 6'd63; 
                    else          bist_addr <= bist_addr + 1'b1;
                end

                CMP0_W1_DOWN: begin
                    if(addr_done) bist_addr <= 6'd63; 
                    else          bist_addr <= bist_addr - 1'b1;
                end

                CMP1_W0_DOWN: begin
                    if(addr_done) bist_addr <= 6'd0; 
                    else          bist_addr <= bist_addr - 1'b1;
                end

                CMP0_FINAL: begin
                    if(addr_done) bist_addr <= 6'd0;
                    else          bist_addr <= bist_addr + 1'b1;
                end

                default: bist_addr <= 6'd0;
            endcase
        end
    end

    // Error Register Capture 
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            bist_fail   <= 1'b0;
            fail_addr   <= 6'd0;
            actual_data <= {DATA_WIDTH{1'b0}};
        end else if(state == IDLE && test_mode) begin
            bist_fail   <= 1'b0;
            fail_addr   <= 6'd0;
            actual_data <= {DATA_WIDTH{1'b0}};
        end else if (compare_en) begin
            if(ram_dout != expected_data) begin
                bist_fail <= 1'b1;
                if (!bist_fail) begin 
                    fail_addr   <= addr_delayed; 
                    actual_data <= ram_dout; 
                end
            end
        end
    end

endmodule
