module axi2per_res_channel
#(
   parameter PER_DATA_WIDTH = 256,
   parameter AXI_ADDR_WIDTH = 32,
   parameter AXI_DATA_WIDTH = 64,
   parameter AXI_USER_WIDTH = 6,
   parameter AXI_ID_WIDTH   = 3,
   parameter PER_ID_WIDTH   = 2**AXI_ID_WIDTH   // one-hot: 2^AXI_ID_WIDTH bits
)
(
   input  logic                      clk_i,
   input  logic                      rst_ni,
   input logic                       per_master_r_valid_i,
   input logic                       per_master_r_opc_i,
   input logic [PER_DATA_WIDTH-1:0]  per_master_r_rdata_i,
   input logic [PER_ID_WIDTH-1:0]    per_master_r_id_i,
   input logic [AXI_USER_WIDTH-1:0]  per_master_r_user_i,
   output logic                      axi_slave_r_valid_o,
   output logic [AXI_DATA_WIDTH-1:0] axi_slave_r_data_o,
   output logic [1:0]                axi_slave_r_resp_o,
   output logic                      axi_slave_r_last_o,
   output logic [AXI_ID_WIDTH-1:0]   axi_slave_r_id_o,
   output logic [AXI_USER_WIDTH-1:0] axi_slave_r_user_o,
   input  logic                      axi_slave_r_ready_i,
   output logic                      axi_slave_b_valid_o,
   output logic [1:0]                axi_slave_b_resp_o,
   output logic [AXI_ID_WIDTH-1:0]   axi_slave_b_id_o,
   output logic [AXI_USER_WIDTH-1:0] axi_slave_b_user_o,
   input  logic                      axi_slave_b_ready_i,
   input logic                       trans_req_i,
   input logic                       trans_we_i,
   input logic [AXI_ID_WIDTH-1:0]    trans_id_i,
   input logic [AXI_ADDR_WIDTH-1:0]  trans_add_i,
   input logic [7:0]                 trans_len_i,
   output logic                      trans_r_valid_o
);
localparam integer      PER_ADDR_WIDTH = AXI_ADDR_WIDTH; // always equal to AXI_ADDR_WIDTH
localparam int unsigned AXI_BE_WIDTH   = AXI_DATA_WIDTH/8;
localparam int unsigned BEAT_RATIO   = (PER_DATA_WIDTH/AXI_DATA_WIDTH);
localparam int unsigned SLOT_W       = (BEAT_RATIO > 1) ? $clog2(BEAT_RATIO) : 1;

logic [PER_DATA_WIDTH-1:0]  rdata_q;
logic [AXI_ID_WIDTH-1:0]   id_q;
logic [AXI_USER_WIDTH-1:0] user_q;
logic [7:0] len_q;
logic is_read_q;
logic [SLOT_W-1:0] base_slot_q;
logic [7:0] beat_q;
logic have_rsp_q;
logic have_bresp_q;
integer rd_slot;

always_ff @(posedge clk_i or negedge rst_ni) begin
 if(!rst_ni) begin
  rdata_q<='0; id_q<='0; user_q<='0; len_q<='0; is_read_q<=0; base_slot_q<='0; beat_q<='0; have_rsp_q<=0; have_bresp_q<=0;
 end else begin
  if(trans_req_i) begin
    is_read_q <= trans_we_i;
    id_q      <= trans_id_i;
    len_q     <= trans_len_i;
    beat_q    <= 0;
    base_slot_q <= trans_add_i[$clog2(PER_DATA_WIDTH/8)-1:$clog2(AXI_BE_WIDTH)];
  end
  if(per_master_r_valid_i) begin
    user_q <= per_master_r_user_i;   // capture user field from peripheral response
    if(is_read_q) begin
      rdata_q <= per_master_r_rdata_i;
      have_rsp_q <= 1'b1;
      beat_q <= 0;
    end else begin
      have_bresp_q <= 1'b1;
    end
  end
  if(axi_slave_r_valid_o && axi_slave_r_ready_i) begin
    if(axi_slave_r_last_o) have_rsp_q <= 1'b0;
    else beat_q <= beat_q + 8'd1;
  end
  if(axi_slave_b_valid_o && axi_slave_b_ready_i) have_bresp_q <= 1'b0;
 end
end

always_comb begin
 axi_slave_r_valid_o=0; axi_slave_r_data_o='0; axi_slave_r_last_o=0; axi_slave_r_id_o=id_q;
 axi_slave_b_valid_o=0; axi_slave_b_id_o=id_q;
 trans_r_valid_o=0;
 if(is_read_q) begin
   if(have_rsp_q) begin
      rd_slot = base_slot_q + beat_q;
      axi_slave_r_valid_o=1;
      if(rd_slot < BEAT_RATIO) axi_slave_r_data_o = rdata_q[rd_slot*AXI_DATA_WIDTH +: AXI_DATA_WIDTH];
      axi_slave_r_last_o = (beat_q == len_q);
      if(axi_slave_r_valid_o && axi_slave_r_ready_i && axi_slave_r_last_o) trans_r_valid_o=1;
   end
 end else begin
   axi_slave_b_valid_o = have_bresp_q;
   if(have_bresp_q && axi_slave_b_ready_i) trans_r_valid_o=1;
 end
end
assign axi_slave_r_resp_o = '0;
assign axi_slave_r_user_o = user_q;   // pass through user field from peripheral response
assign axi_slave_b_resp_o = '0;
assign axi_slave_b_user_o = user_q;   // pass through user field from peripheral response
endmodule
