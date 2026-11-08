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
    output reg  [DATA_WIDTH-1:0] actual_data
);

    // Explicit, alternating March C- states
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
    reg [DATA_WIDTH-1:0] expected_data;
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
            W0_UP:         addr_done = (bist_addr == {ADDR_WIDTH{1'b1}});
            CMP0_W1_UP:    addr_done = (bist_addr == {ADDR_WIDTH{1'b1}});
            CMP1_W0_UP:    addr_done = (bist_addr == {ADDR_WIDTH{1'b1}});
            CMP0_W1_DOWN:  addr_done = (bist_addr == {ADDR_WIDTH{1'b0}});
            CMP1_W0_DOWN:  addr_done = (bist_addr == {ADDR_WIDTH{1'b0}});
            CMP0_FINAL:    addr_done = (bist_addr == {ADDR_WIDTH{1'b1}});
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

            // We hold the expected data steady during the actual verification clock edge (CMP_* states)
            READ0_UP:   expected_data = {DATA_WIDTH{1'b0}};
            CMP0_W1_UP: begin
                bist_we    = 1'b1;
                bist_din   = {DATA_WIDTH{1'b1}}; // Write 1
                expected_data = {DATA_WIDTH{1'b0}}; // Expect 0
                compare_en = 1'b1;
            end

            READ1_UP:   expected_data = {DATA_WIDTH{1'b1}};
            CMP1_W0_UP: begin
                bist_we    = 1'b1;
                bist_din   = {DATA_WIDTH{1'b0}}; // Write 0
                expected_data = {DATA_WIDTH{1'b1}}; // Expect 1
                compare_en = 1'b1;
            end

            READ0_DOWN:   expected_data = {DATA_WIDTH{1'b0}};
            CMP0_W1_DOWN: begin
                bist_we    = 1'b1;
                bist_din   = {DATA_WIDTH{1'b1}}; // Write 1
                expected_data = {DATA_WIDTH{1'b0}}; // Expect 0
                compare_en = 1'b1;
            end

            READ1_DOWN:   expected_data = {DATA_WIDTH{1'b1}};
            CMP1_W0_DOWN: begin
                bist_we    = 1'b1;
                bist_din   = {DATA_WIDTH{1'b0}}; // Write 0
                expected_data = {DATA_WIDTH{1'b1}}; // Expect 1
                compare_en = 1'b1;
            end

            READ0_FINAL: expected_data = {DATA_WIDTH{1'b0}};
            CMP0_FINAL: begin
                expected_data = {DATA_WIDTH{1'b0}};
                compare_en    = 1'b1;
            end

            DONE:        bist_finish   = 1'b1;
        endcase
    end

    // Pipeline-Aligned Address Generation
    // This explicitly prevents looking at uninitialized boundaries or missing target cells.
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            bist_addr    <= {ADDR_WIDTH{1'b0}};
            addr_delayed <= {ADDR_WIDTH{1'b0}};
        end else begin
            addr_delayed <= bist_addr;

            case(state)
                IDLE: bist_addr <= {ADDR_WIDTH{1'b0}};

                W0_UP: begin
                    if(addr_done) bist_addr <= {ADDR_WIDTH{1'b0}}; // Smooth handoff to READ0_UP
                    else          bist_addr <= bist_addr + 1'b1;
                end

                // Freeze addresses during read setup cycles to accommodate synchronous RAM array latency
                READ0_UP, READ1_UP, READ0_DOWN, READ1_DOWN, READ0_FINAL: begin
                    bist_addr <= bist_addr; 
                end

                // Steps address values cleanly only AFTER the write/comparison has executed
                CMP0_W1_UP: begin
                    if(addr_done) bist_addr <= {ADDR_WIDTH{1'b0}}; // Hand off to READ1_UP at 0
                    else          bist_addr <= bist_addr + 1'b1;
                end

                CMP1_W0_UP: begin
                    if(addr_done) bist_addr <= {ADDR_WIDTH{1'b1}}; // Hand off to READ0_DOWN at 63
                    else          bist_addr <= bist_addr + 1'b1;
                end

                // Counting Down Passes
                CMP0_W1_DOWN: begin
                    if(addr_done) bist_addr <= {ADDR_WIDTH{1'b1}}; // Hand off to READ1_DOWN at 63
                    else          bist_addr <= bist_addr - 1'b1;
                end

                CMP1_W0_DOWN: begin
                    if(addr_done) bist_addr <= {ADDR_WIDTH{1'b0}}; // Hand off to READ0_FINAL at 0
                    else          bist_addr <= bist_addr - 1'b1;
                end

                CMP0_FINAL: begin
                    if(addr_done) bist_addr <= {ADDR_WIDTH{1'b0}};
                    else          bist_addr <= bist_addr + 1'b1;
                end

                default: bist_addr <= {ADDR_WIDTH{1'b0}};
            endcase
        end
    end

    // Error Register Capture 
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            bist_fail   <= 1'b0;
            fail_addr   <= {ADDR_WIDTH{1'b0}};
            actual_data <= {DATA_WIDTH{1'b0}};
        end else if(state == IDLE && test_mode) begin
            bist_fail   <= 1'b0;
            fail_addr   <= {ADDR_WIDTH{1'b0}};
            actual_data <= {DATA_WIDTH{1'b0}};
        end else if (compare_en) begin
            if(ram_dout != expected_data) begin
                bist_fail <= 1'b1;
                if (!bist_fail) begin // Captures the exact fault instance beautifully
                    fail_addr   <= addr_delayed;
                    actual_data <= ram_dout;
                end
            end
        end
    end

endmodule
