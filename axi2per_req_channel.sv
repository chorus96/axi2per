module axi2per_req_channel
#(
   parameter PER_ADDR_WIDTH = 32,
   parameter PER_ID_WIDTH   = 5,
   parameter PER_DATA_WIDTH = 256,
   parameter AXI_ADDR_WIDTH = 32,
   parameter AXI_DATA_WIDTH = 64,
   parameter AXI_USER_WIDTH = 6,
   parameter AXI_ID_WIDTH   = 3,
   parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH/8,
   parameter PER_BE_WIDTH   = PER_DATA_WIDTH/8
)
(
   input logic                       clk_i,
   input logic                       rst_ni,
   input  logic                      axi_slave_aw_valid_i,
   input  logic [AXI_ADDR_WIDTH-1:0] axi_slave_aw_addr_i,
   input  logic [2:0]                axi_slave_aw_prot_i,
   input  logic [3:0]                axi_slave_aw_region_i,
   input  logic [7:0]                axi_slave_aw_len_i,
   input  logic [2:0]                axi_slave_aw_size_i,
   input  logic [1:0]                axi_slave_aw_burst_i,
   input  logic                      axi_slave_aw_lock_i,
   input  logic [3:0]                axi_slave_aw_cache_i,
   input  logic [3:0]                axi_slave_aw_qos_i,
   input  logic [AXI_ID_WIDTH-1:0]   axi_slave_aw_id_i,
   input  logic [AXI_USER_WIDTH-1:0] axi_slave_aw_user_i,
   output logic                      axi_slave_aw_ready_o,
   input  logic                      axi_slave_ar_valid_i,
   input  logic [AXI_ADDR_WIDTH-1:0] axi_slave_ar_addr_i,
   input  logic [2:0]                axi_slave_ar_prot_i,
   input  logic [3:0]                axi_slave_ar_region_i,
   input  logic [7:0]                axi_slave_ar_len_i,
   input  logic [2:0]                axi_slave_ar_size_i,
   input  logic [1:0]                axi_slave_ar_burst_i,
   input  logic                      axi_slave_ar_lock_i,
   input  logic [3:0]                axi_slave_ar_cache_i,
   input  logic [3:0]                axi_slave_ar_qos_i,
   input  logic [AXI_ID_WIDTH-1:0]   axi_slave_ar_id_i,
   input  logic [AXI_USER_WIDTH-1:0] axi_slave_ar_user_i,
   output logic                      axi_slave_ar_ready_o,
   input  logic                      axi_slave_w_valid_i,
   input  logic [AXI_DATA_WIDTH-1:0] axi_slave_w_data_i,
   input  logic [AXI_STRB_WIDTH-1:0] axi_slave_w_strb_i,
   input  logic [AXI_USER_WIDTH-1:0] axi_slave_w_user_i,
   input  logic                      axi_slave_w_last_i,
   output logic                      axi_slave_w_ready_o,
   output logic                       per_master_req_o,
   output logic [PER_ADDR_WIDTH-1:0]  per_master_add_o,
   output logic                       per_master_we_o,      // 1=WRITE, 0=READ (standard PULP convention)
   output logic [PER_DATA_WIDTH-1:0]  per_master_wdata_o,
   output logic [PER_BE_WIDTH-1:0]    per_master_be_o,
   output logic [PER_ID_WIDTH-1:0]    per_master_id_o,
   output logic [AXI_USER_WIDTH-1:0]  per_master_user_o,
   input  logic                       per_master_gnt_i,
   output logic                      trans_req_o,
   output logic                      trans_we_o,
   output logic [AXI_ID_WIDTH-1:0]   trans_id_o,
   output logic [AXI_ADDR_WIDTH-1:0] trans_add_o,
   output logic [7:0]                trans_len_o,
   input  logic                      trans_r_valid_i,
   output logic                      busy_o
);
localparam int unsigned AXI_BE_WIDTH = AXI_DATA_WIDTH/8;
localparam int unsigned BEAT_RATIO   = (PER_DATA_WIDTH/AXI_DATA_WIDTH);
localparam int unsigned SLOT_W       = (BEAT_RATIO > 1) ? $clog2(BEAT_RATIO) : 1;

typedef enum logic [1:0] {IDLE, COLLECT, WAIT_RESP} state_t;
state_t state_q, state_d;
logic [PER_DATA_WIDTH-1:0] wdata_buf_q, wdata_buf_d;
logic [PER_BE_WIDTH-1:0]   be_buf_q, be_buf_d;
logic [7:0]                beat_cnt_q, beat_cnt_d;
logic [7:0]                beats_exp_q, beats_exp_d;
logic [AXI_ADDR_WIDTH-1:0] aw_addr_q, aw_addr_d;
logic [AXI_ID_WIDTH-1:0]   aw_id_q, aw_id_d;
logic [7:0]                aw_len_q, aw_len_d;
logic [SLOT_W-1:0]         base_slot_q, base_slot_d;
logic [AXI_USER_WIDTH-1:0] aw_user_q,   aw_user_d;
integer wr_slot;

always_comb begin
  state_d=state_q; wdata_buf_d=wdata_buf_q; be_buf_d=be_buf_q; beat_cnt_d=beat_cnt_q; beats_exp_d=beats_exp_q;
  aw_addr_d=aw_addr_q; aw_id_d=aw_id_q; aw_len_d=aw_len_q; base_slot_d=base_slot_q;
  axi_slave_aw_ready_o=0; axi_slave_ar_ready_o=0; axi_slave_w_ready_o=0;
  per_master_req_o=0; per_master_add_o='0; per_master_we_o=0; per_master_wdata_o='0; per_master_be_o='0;
  per_master_id_o='0; per_master_user_o='0;
  trans_req_o=0; trans_we_o=0; trans_id_o='0; trans_add_o='0; trans_len_o='0;
  busy_o = (state_q!=IDLE);

  case(state_q)
    IDLE: begin
      if (axi_slave_ar_valid_i) begin
        // READ: we_o=0 (standard PULP: 0=read)
        per_master_req_o=1; per_master_we_o=0; per_master_add_o=axi_slave_ar_addr_i;
        per_master_id_o   = {{(PER_ID_WIDTH-1){1'b0}}, 1'b1} << axi_slave_ar_id_i; // binary→one-hot
        per_master_user_o = axi_slave_ar_user_i;
        if (per_master_gnt_i) begin
          axi_slave_ar_ready_o=1; trans_req_o=1; trans_we_o=1; trans_id_o=axi_slave_ar_id_i; trans_add_o=axi_slave_ar_addr_i; trans_len_o=axi_slave_ar_len_i;
          state_d=WAIT_RESP;
        end
      end else if (axi_slave_aw_valid_i) begin
        axi_slave_aw_ready_o=1;
        aw_addr_d=axi_slave_aw_addr_i; aw_id_d=axi_slave_aw_id_i; aw_len_d=axi_slave_aw_len_i;
        aw_user_d=axi_slave_aw_user_i;
        beats_exp_d=axi_slave_aw_len_i+8'd1; beat_cnt_d='0; wdata_buf_d='0; be_buf_d='0;
        base_slot_d = axi_slave_aw_addr_i[$clog2(PER_BE_WIDTH)-1:$clog2(AXI_BE_WIDTH)];
        state_d=COLLECT;
      end
    end
    COLLECT: begin
      axi_slave_w_ready_o=1;
      if (axi_slave_w_valid_i) begin
        wr_slot = base_slot_q + beat_cnt_q;
        if (wr_slot < BEAT_RATIO) begin
          wdata_buf_d[wr_slot*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = axi_slave_w_data_i;
          be_buf_d[wr_slot*AXI_BE_WIDTH +: AXI_BE_WIDTH] = axi_slave_w_strb_i;
        end
        beat_cnt_d = beat_cnt_q + 8'd1;
        if ((beat_cnt_q + 8'd1 == beats_exp_q) || axi_slave_w_last_i) begin
          // WRITE: we_o=1 (standard PULP: 1=write)
          per_master_req_o=1; per_master_we_o=1; per_master_add_o=aw_addr_q;
          per_master_wdata_o=wdata_buf_d; per_master_be_o=be_buf_d;
          per_master_id_o   = {{(PER_ID_WIDTH-1){1'b0}}, 1'b1} << aw_id_q;       // binary→one-hot
          per_master_user_o = aw_user_q;
          if (per_master_gnt_i) begin
            trans_req_o=1; trans_we_o=0; trans_id_o=aw_id_q; trans_add_o=aw_addr_q; trans_len_o=aw_len_q;
            state_d=WAIT_RESP;
          end
        end
      end
    end
    WAIT_RESP: begin
      if (trans_r_valid_i) state_d=IDLE;
    end
  endcase
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if(!rst_ni) begin
    state_q<=IDLE; wdata_buf_q<='0; be_buf_q<='0; beat_cnt_q<='0; beats_exp_q<='0; aw_addr_q<='0; aw_id_q<='0; aw_len_q<='0; base_slot_q<='0; aw_user_q<='0;
  end else begin
    state_q<=state_d; wdata_buf_q<=wdata_buf_d; be_buf_q<=be_buf_d; beat_cnt_q<=beat_cnt_d; beats_exp_q<=beats_exp_d; aw_addr_q<=aw_addr_d; aw_id_q<=aw_id_d; aw_len_q<=aw_len_d; base_slot_q<=base_slot_d; aw_user_q<=aw_user_d;
  end
end
endmodule
