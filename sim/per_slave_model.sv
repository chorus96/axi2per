// Copyright 2024 - Peripheral Interconnect Slave RTL Model for axi2per simulation
//
// Simple 32-bit peripheral memory model.
// Protocol:
//   REQ phase : req_i asserted with addr/we_n/wdata/be
//               gnt_o may assert same cycle (combinational) or later
//   RESP phase: r_valid_o asserted RESP_DELAY cycles after gnt_o
//               r_opc_o = 0 (no error), r_rdata_o = read data (0 for writes)
//
// we_ni convention (matches axi2per output per_master_we_no):
//   1 = READ
//   0 = WRITE

module per_slave_model #(
    parameter int unsigned ADDR_WIDTH  = 32,
    parameter int unsigned MEM_WORDS   = 256,   // 256 x 32-bit = 1 KiB
    parameter int unsigned RESP_DELAY  = 1      // cycles between gnt and r_valid
) (
    input  logic                   clk_i,
    input  logic                   rst_ni,

    // --- Request channel ---
    input  logic                   req_i,
    input  logic [ADDR_WIDTH-1:0]  add_i,
    input  logic                   we_ni,       // 1=READ, 0=WRITE
    input  logic [31:0]            wdata_i,
    input  logic [3:0]             be_i,
    output logic                   gnt_o,

    // --- Response channel ---
    output logic                   r_valid_o,
    output logic                   r_opc_o,
    output logic [31:0]            r_rdata_o
);

    // -----------------------------------------------------------------------
    // Internal memory
    // -----------------------------------------------------------------------
    logic [31:0] mem [0:MEM_WORDS-1];

    // Word index (byte address >> 2)
    logic [$clog2(MEM_WORDS)-1:0] word_idx;
    assign word_idx = add_i[$clog2(MEM_WORDS)+1:2];

    // -----------------------------------------------------------------------
    // Grant: assert immediately when a request arrives (zero-latency grant)
    // -----------------------------------------------------------------------
    assign gnt_o = req_i;

    // -----------------------------------------------------------------------
    // Response pipeline
    // -----------------------------------------------------------------------
    // Each entry captures: {we_n, word_idx}
    localparam int unsigned PIPE_W = 1 + $clog2(MEM_WORDS);

    logic [PIPE_W-1:0] pipe_data [0:RESP_DELAY-1];
    logic              pipe_vld  [0:RESP_DELAY-1];

    genvar gi;
    generate
        for (gi = 0; gi < RESP_DELAY; gi++) begin : gen_pipe
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) begin
                    pipe_vld [gi] <= 1'b0;
                    pipe_data[gi] <= '0;
                end else begin
                    if (gi == 0) begin
                        pipe_vld [gi] <= req_i & gnt_o;
                        pipe_data[gi] <= {we_ni, word_idx};
                    end else begin
                        pipe_vld [gi] <= pipe_vld [gi-1];
                        pipe_data[gi] <= pipe_data[gi-1];
                    end
                end
            end
        end
    endgenerate

    // Final stage outputs
    logic                          resp_we_n;
    logic [$clog2(MEM_WORDS)-1:0]  resp_idx;

    assign resp_we_n = pipe_data[RESP_DELAY-1][PIPE_W-1];
    assign resp_idx  = pipe_data[RESP_DELAY-1][$clog2(MEM_WORDS)-1:0];

    assign r_valid_o = pipe_vld[RESP_DELAY-1];
    assign r_opc_o   = 1'b0;   // no error
    assign r_rdata_o = (r_valid_o && resp_we_n) ? mem[resp_idx] : 32'h0;

    // -----------------------------------------------------------------------
    // Write path  (execute on the cycle gnt is asserted)
    // -----------------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (req_i && gnt_o && !we_ni) begin
            // byte-enable write
            if (be_i[0]) mem[word_idx][ 7: 0] <= wdata_i[ 7: 0];
            if (be_i[1]) mem[word_idx][15: 8] <= wdata_i[15: 8];
            if (be_i[2]) mem[word_idx][23:16] <= wdata_i[23:16];
            if (be_i[3]) mem[word_idx][31:24] <= wdata_i[31:24];
        end
    end

    // -----------------------------------------------------------------------
    // Memory initialisation (power-on and reset)
    // -----------------------------------------------------------------------
    initial begin
        for (int i = 0; i < MEM_WORDS; i++) begin
            mem[i] = 32'h0;
        end
    end

endmodule
