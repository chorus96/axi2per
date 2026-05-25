module per_slave_model #(
    parameter int unsigned ADDR_WIDTH  = 32,
    parameter int unsigned DATA_WIDTH  = 256,
    parameter int unsigned MEM_WORDS   = 256,
    parameter int unsigned RESP_DELAY  = 1
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,
    input  logic                      req_i,
    input  logic [ADDR_WIDTH-1:0]     add_i,
    input  logic                      we_ni,
    input  logic [DATA_WIDTH-1:0]     wdata_i,
    input  logic [DATA_WIDTH/8-1:0]   be_i,
    output logic                      gnt_o,
    output logic                      r_valid_o,
    output logic                      r_opc_o,
    output logic [DATA_WIDTH-1:0]     r_rdata_o
);
logic [DATA_WIDTH-1:0] mem [0:MEM_WORDS-1];
logic [$clog2(MEM_WORDS)-1:0] word_idx;
assign word_idx = add_i[$clog2(MEM_WORDS)+$clog2(DATA_WIDTH/8)-1:$clog2(DATA_WIDTH/8)];
assign gnt_o = req_i;
localparam int unsigned PIPE_W = 1 + $clog2(MEM_WORDS);
logic [PIPE_W-1:0] pipe_data [0:RESP_DELAY-1];
logic pipe_vld [0:RESP_DELAY-1];
for (genvar gi=0; gi<RESP_DELAY; gi++) begin
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin pipe_vld[gi]<='0; pipe_data[gi]<='0; end
    else if(gi==0) begin pipe_vld[gi] <= req_i & gnt_o; pipe_data[gi] <= {we_ni,word_idx}; end
    else begin pipe_vld[gi] <= pipe_vld[gi-1]; pipe_data[gi] <= pipe_data[gi-1]; end
  end
end
wire resp_we_n = pipe_data[RESP_DELAY-1][PIPE_W-1];
wire [$clog2(MEM_WORDS)-1:0] resp_idx = pipe_data[RESP_DELAY-1][$clog2(MEM_WORDS)-1:0];
assign r_valid_o = pipe_vld[RESP_DELAY-1];
assign r_opc_o = 1'b0;
assign r_rdata_o = (r_valid_o && resp_we_n) ? mem[resp_idx] : '0;
always_ff @(posedge clk_i) begin
  if(req_i && gnt_o && !we_ni) begin
    for (int b=0; b<DATA_WIDTH/8; b++) if (be_i[b]) mem[word_idx][8*b +: 8] <= wdata_i[8*b +: 8];
  end
end
initial for (int i=0;i<MEM_WORDS;i++) mem[i]='0;
endmodule
