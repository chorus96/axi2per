// Peripheral Interconnect Slave RTL Model
// Matches the standard PULP peripheral protocol used by per2axi:
//   we_i = 1 → WRITE,  we_i = 0 → READ
module per_slave_model #(
    parameter int unsigned ADDR_WIDTH  = 32,
    parameter int unsigned DATA_WIDTH  = 256,
    parameter int unsigned PER_ID_WIDTH  = 5,
    parameter int unsigned USER_WIDTH  = 6,
    parameter int unsigned MEM_WORDS   = 256,
    parameter int unsigned RESP_DELAY  = 1
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,
    // Request channel
    input  logic                        req_i,
    input  logic [ADDR_WIDTH-1:0]       add_i,
    input  logic                        we_i,        // 1=WRITE, 0=READ
    input  logic [DATA_WIDTH-1:0]       wdata_i,
    input  logic [DATA_WIDTH/8-1:0]     be_i,
    input  logic [PER_ID_WIDTH-1:0]     id_i,
    input  logic [USER_WIDTH-1:0]       user_i,
    output logic                        gnt_o,
    // Response channel
    output logic                        r_valid_o,
    output logic                        r_opc_o,
    output logic [DATA_WIDTH-1:0]       r_rdata_o,
    output logic [PER_ID_WIDTH-1:0]     r_id_o,
    output logic [USER_WIDTH-1:0]       r_user_o
);

logic [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];
logic [$clog2(MEM_WORDS)-1:0] word_idx;
assign word_idx = add_i[$clog2(MEM_WORDS)+$clog2(DATA_WIDTH/8)-1 : $clog2(DATA_WIDTH/8)];

// Zero-latency grant
assign gnt_o = req_i;

// Response pipeline: stores {we_i, id_i, user_i, word_idx}
localparam int unsigned PIPE_W = 1 + PER_ID_WIDTH + USER_WIDTH + $clog2(MEM_WORDS);
logic [PIPE_W-1:0] pipe_data [0:RESP_DELAY-1];
logic              pipe_vld  [0:RESP_DELAY-1];

for (genvar gi = 0; gi < RESP_DELAY; gi++) begin : gen_pipe
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pipe_vld [gi] <= '0;
            pipe_data[gi] <= '0;
        end else if (gi == 0) begin
            pipe_vld [gi] <= req_i & gnt_o;
            pipe_data[gi] <= {we_i, id_i, user_i, word_idx};
        end else begin
            pipe_vld [gi] <= pipe_vld [gi-1];
            pipe_data[gi] <= pipe_data[gi-1];
        end
    end
end

// Unpack pipeline output
wire                          resp_we   = pipe_data[RESP_DELAY-1][PIPE_W-1];
wire [PER_ID_WIDTH-1:0]       resp_id   = pipe_data[RESP_DELAY-1][PIPE_W-2 -: PER_ID_WIDTH];
wire [USER_WIDTH-1:0]         resp_user = pipe_data[RESP_DELAY-1][PIPE_W-2-PER_ID_WIDTH -: USER_WIDTH];
wire [$clog2(MEM_WORDS)-1:0]  resp_idx  = pipe_data[RESP_DELAY-1][$clog2(MEM_WORDS)-1:0];

assign r_valid_o  = pipe_vld[RESP_DELAY-1];
assign r_opc_o    = 1'b0;
assign r_rdata_o  = (r_valid_o && !resp_we) ? mem[resp_idx] : '0;  // return data on READ
assign r_id_o     = r_valid_o ? resp_id   : '0;
assign r_user_o   = r_valid_o ? resp_user : '0;

// Write path
always_ff @(posedge clk_i) begin
    if (req_i && gnt_o && we_i) begin
        for (int b = 0; b < DATA_WIDTH/8; b++)
            if (be_i[b]) mem[word_idx][8*b +: 8] <= wdata_i[8*b +: 8];
    end
end

initial for (int i = 0; i < MEM_WORDS; i++) mem[i] = '0;

endmodule
