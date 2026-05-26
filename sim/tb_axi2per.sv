`timescale 1ns/1ps
// Test configuration: PER_DATA_WIDTH=512, AXI_DATA_WIDTH=128, 4-beat AXI bursts
// BEAT_RATIO = 512/128 = 4  →  one peripheral 512-bit word = four 128-bit AXI beats
// Verifies: data, ID (one-hot), and USER field propagation through axi2per
module tb_axi2per;
localparam int unsigned PER_ADDR_WIDTH = 32;
localparam int unsigned PER_DATA_WIDTH = 512;
localparam int unsigned AXI_ADDR_WIDTH = 32;
localparam int unsigned AXI_DATA_WIDTH = 128;
localparam int unsigned AXI_USER_WIDTH = 6;
localparam int unsigned AXI_ID_WIDTH   = 3;
localparam int unsigned PER_ID_WIDTH   = 2**AXI_ID_WIDTH; // one-hot: 8 bits
localparam int unsigned BUFFER_DEPTH   = 2;
localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;  // 16

// Clock & reset
logic clk=0;
// verilator lint_off BLKSEQ
always #5 clk=~clk;
// verilator lint_on BLKSEQ
logic rst_n;
initial begin rst_n=0; repeat(4) @(posedge clk); rst_n=1; end

// AXI signals
logic aw_valid; logic [AXI_ADDR_WIDTH-1:0] aw_addr; logic [7:0] aw_len;
logic [2:0] aw_size; logic [1:0] aw_burst; logic [AXI_ID_WIDTH-1:0] aw_id;
logic [AXI_USER_WIDTH-1:0] aw_user; logic aw_ready;

logic ar_valid; logic [AXI_ADDR_WIDTH-1:0] ar_addr; logic [7:0] ar_len;
logic [2:0] ar_size; logic [1:0] ar_burst; logic [AXI_ID_WIDTH-1:0] ar_id;
logic [AXI_USER_WIDTH-1:0] ar_user; logic ar_ready;

logic w_valid; logic [AXI_DATA_WIDTH-1:0] w_data; logic [AXI_STRB_WIDTH-1:0] w_strb;
logic w_last; logic w_ready;

logic r_valid; logic [AXI_DATA_WIDTH-1:0] r_data; logic r_last;
logic [AXI_ID_WIDTH-1:0] r_id; logic [AXI_USER_WIDTH-1:0] r_user; logic r_ready=1;

logic b_valid; logic [AXI_ID_WIDTH-1:0] b_id;
logic [AXI_USER_WIDTH-1:0] b_user; logic b_ready=1;

// Peripheral signals
logic                        per_req;
logic [PER_ADDR_WIDTH-1:0]   per_add;
logic                        per_we;
logic [PER_DATA_WIDTH-1:0]   per_wdata;
logic [PER_DATA_WIDTH/8-1:0] per_be;
logic [PER_ID_WIDTH-1:0]     per_id;     // one-hot encoded
logic [AXI_USER_WIDTH-1:0]   per_user;   // forwarded user field
logic                        per_gnt;
logic                        per_r_valid;
logic                        per_r_opc;
logic [PER_DATA_WIDTH-1:0]   per_r_rdata;
logic [PER_ID_WIDTH-1:0]     per_r_id;
logic [AXI_USER_WIDTH-1:0]   per_r_user; // echoed user from peripheral
logic                        busy;

// DUT  (ports renamed for AMD Vivado IP packaging: aclk/aresetn/s_axi_*)
axi2per #(
  .PER_DATA_WIDTH(PER_DATA_WIDTH),
  .PER_ID_WIDTH(PER_ID_WIDTH),
  .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH), .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
  .AXI_USER_WIDTH(AXI_USER_WIDTH), .AXI_ID_WIDTH(AXI_ID_WIDTH),
  .BUFFER_DEPTH(BUFFER_DEPTH)
) dut (
  .aclk(clk), .aresetn(rst_n), .test_en_i(1'b0),
  // AW
  .s_axi_awvalid(aw_valid), .s_axi_awaddr(aw_addr),
  .s_axi_awprot('0), .s_axi_awregion('0),
  .s_axi_awlen(aw_len), .s_axi_awsize(aw_size),
  .s_axi_awburst(aw_burst), .s_axi_awlock('0),
  .s_axi_awcache('0), .s_axi_awqos('0),
  .s_axi_awid(aw_id), .s_axi_awuser(aw_user),   // ← user connected
  .s_axi_awready(aw_ready),
  // AR
  .s_axi_arvalid(ar_valid), .s_axi_araddr(ar_addr),
  .s_axi_arprot('0), .s_axi_arregion('0),
  .s_axi_arlen(ar_len), .s_axi_arsize(ar_size),
  .s_axi_arburst(ar_burst), .s_axi_arlock('0),
  .s_axi_arcache('0), .s_axi_arqos('0),
  .s_axi_arid(ar_id), .s_axi_aruser(ar_user),   // ← user connected
  .s_axi_arready(ar_ready),
  // W
  .s_axi_wvalid(w_valid), .s_axi_wdata(w_data),
  .s_axi_wstrb(w_strb), .s_axi_wuser('0),
  .s_axi_wlast(w_last), .s_axi_wready(w_ready),
  // R
  .s_axi_rvalid(r_valid), .s_axi_rdata(r_data),
  .s_axi_rresp(), .s_axi_rlast(r_last),
  .s_axi_rid(r_id), .s_axi_ruser(r_user),       // ← user connected
  .s_axi_rready(r_ready),
  // B
  .s_axi_bvalid(b_valid), .s_axi_bresp(),
  .s_axi_bid(b_id), .s_axi_buser(b_user),       // ← user connected
  .s_axi_bready(b_ready),
  // Peripheral master
  .per_master_req_o(per_req), .per_master_add_o(per_add),
  .per_master_we_o(per_we),   .per_master_wdata_o(per_wdata),
  .per_master_be_o(per_be),   .per_master_id_o(per_id),
  .per_master_user_o(per_user), .per_master_gnt_i(per_gnt),
  .per_master_r_valid_i(per_r_valid), .per_master_r_opc_i(per_r_opc),
  .per_master_r_rdata_i(per_r_rdata), .per_master_r_id_i(per_r_id),
  .per_master_r_user_i(per_r_user),
  .busy_o(busy)
);

// Peripheral slave model
per_slave_model #(
  .ADDR_WIDTH(PER_ADDR_WIDTH), .DATA_WIDTH(PER_DATA_WIDTH),
  .PER_ID_WIDTH(PER_ID_WIDTH),
  .MEM_WORDS(256), .RESP_DELAY(1)
) per (
  .clk_i(clk), .rst_ni(rst_n),
  .req_i(per_req), .add_i(per_add), .we_i(per_we),
  .wdata_i(per_wdata), .be_i(per_be),
  .id_i(per_id), .user_i(per_user),
  .gnt_o(per_gnt),
  .r_valid_o(per_r_valid), .r_opc_o(per_r_opc),
  .r_rdata_o(per_r_rdata), .r_id_o(per_r_id), .r_user_o(per_r_user)
);

// ---------------------------------------------------------------
// Peripheral-side monitor: per_req 사이클마다 ID/USER 출력
// ---------------------------------------------------------------
always @(posedge clk) begin
  if (rst_n && per_req) begin
    if (!$onehot(per_id))
      $fatal(1, "[ONE-HOT FAIL] per_id is NOT one-hot at %0t ns: per_id=%b (we=%b addr=0x%08h)",
             $time, per_id, per_we, per_add);
    $display("  [per_req] per_id=%b  per_user=0x%02h  (we=%b  addr=0x%08h)",
             per_id, per_user, per_we, per_add);
  end
end

// ---------------------------------------------------------------
// Task: 4-beat AXI write with USER field verification
//   aw_user → per_master_user_o → peripheral echoes →
//   per_master_r_user_i → axi_slave_b_user_o
// ---------------------------------------------------------------
task burst_write4(
  input [31:0]               addr,
  input [127:0]              d0, d1, d2, d3,
  input [AXI_ID_WIDTH-1:0]   id,
  input [AXI_USER_WIDTH-1:0] user
);
begin
  @(posedge clk);
  aw_valid<=1; aw_addr<=addr; aw_len<=8'd3;
  aw_size<=3'b100; aw_burst<=2'b01; aw_id<=id; aw_user<=user;
  wait(aw_ready); @(posedge clk); aw_valid<=0;

  w_valid<=1; w_strb<='1;
  w_data<=d0; w_last<=0; wait(w_ready); @(posedge clk);
  w_data<=d1; w_last<=0; wait(w_ready); @(posedge clk);
  w_data<=d2; w_last<=0; wait(w_ready); @(posedge clk);
  w_data<=d3; w_last<=1; wait(w_ready); @(posedge clk);
  w_valid<=0; w_last<=0;

  wait(b_valid);
  if (b_id !== id)
    $fatal(1,"[WRITE] BID mismatch: got %0d expected %0d", b_id, id);
  if (b_user !== user)
    $fatal(1,"[WRITE] BUSER mismatch: got 0x%02h expected 0x%02h", b_user, user);
  $display("    b_user=0x%02h  <- matches aw_user=0x%02h  OK", b_user, user);
end
endtask

// ---------------------------------------------------------------
// Task: 4-beat AXI read with USER field verification
//   ar_user → per_master_user_o → peripheral echoes →
//   per_master_r_user_i → axi_slave_r_user_o (all beats)
// ---------------------------------------------------------------
task burst_read4(
  input [31:0]               addr,
  input [127:0]              e0, e1, e2, e3,
  input [AXI_ID_WIDTH-1:0]   id,
  input [AXI_USER_WIDTH-1:0] user
);
  reg [127:0] got [0:3];
  int         i;
begin
  @(posedge clk);
  ar_valid<=1; ar_addr<=addr; ar_len<=8'd3;
  ar_size<=3'b100; ar_burst<=2'b01; ar_id<=id; ar_user<=user;
  wait(ar_ready); @(posedge clk); ar_valid<=0;

  for (i = 0; i < 4; i++) begin
    @(posedge clk);
    while (!r_valid) @(posedge clk);
    got[i] = r_data;
    if (r_id !== id)
      $fatal(1,"[READ beat %0d] RID mismatch: got %0d expected %0d", i, r_id, id);
    if (r_user !== user)
      $fatal(1,"[READ beat %0d] RUSER mismatch: got 0x%02h expected 0x%02h",
             i, r_user, user);
  end
  $display("    r_user=0x%02h  <- matches ar_user=0x%02h  OK (all 4 beats)", r_user, user);

  if (got[0] !== e0 || got[1] !== e1 || got[2] !== e2 || got[3] !== e3)
    $fatal(1,
      "[READ] Data mismatch:\n  beat0: got %h  exp %h\n  beat1: got %h  exp %h\n  beat2: got %h  exp %h\n  beat3: got %h  exp %h",
      got[0], e0, got[1], e1, got[2], e2, got[3], e3);
end
endtask

// ---------------------------------------------------------------
// Stimulus
// ---------------------------------------------------------------
initial begin
  aw_valid=0; aw_addr=0; aw_len=0; aw_size=0; aw_burst=0; aw_id=0; aw_user=0;
  ar_valid=0; ar_addr=0; ar_len=0; ar_size=0; ar_burst=0; ar_id=0; ar_user=0;
  w_valid=0;  w_data=0;  w_strb=0; w_last=0;

  wait(rst_n);

  // ----------------------------------------------------------
  // Test 1: write with aw_user=6'h15, read with ar_user=6'h15
  //   Verify b_user==0x15 and r_user==0x15 on all beats
  // ----------------------------------------------------------
  $display("\n--- Test 1: aw_user=0x15, ar_user=0x15 ---");
  burst_write4(32'h0000_0080,
    128'h1111_1111_1111_1111_1111_1111_1111_1111,
    128'h2222_2222_2222_2222_2222_2222_2222_2222,
    128'h3333_3333_3333_3333_3333_3333_3333_3333,
    128'h4444_4444_4444_4444_4444_4444_4444_4444,
    3'd1, 6'h15);

  burst_read4(32'h0000_0080,
    128'h1111_1111_1111_1111_1111_1111_1111_1111,
    128'h2222_2222_2222_2222_2222_2222_2222_2222,
    128'h3333_3333_3333_3333_3333_3333_3333_3333,
    128'h4444_4444_4444_4444_4444_4444_4444_4444,
    3'd1, 6'h15);
  $display("PASS  [test 1] user=0x15 write+read @ 0x0080 (id=1)");

  // ----------------------------------------------------------
  // Test 2: different address, different user and ID
  //   Verify user values are independent per transaction
  // ----------------------------------------------------------
  $display("\n--- Test 2: aw_user=0x2A, ar_user=0x2A, id=5 ---");
  burst_write4(32'h0000_0100,
    128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111,
    128'h2222_3333_4444_5555_6666_7777_8888_9999,
    128'hDEAD_BEEF_CAFE_BABE_1234_5678_9ABC_DEF0,
    128'hFEED_FACE_C0FF_EE00_0102_0304_0506_0708,
    3'd5, 6'h2A);

  burst_read4(32'h0000_0100,
    128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111,
    128'h2222_3333_4444_5555_6666_7777_8888_9999,
    128'hDEAD_BEEF_CAFE_BABE_1234_5678_9ABC_DEF0,
    128'hFEED_FACE_C0FF_EE00_0102_0304_0506_0708,
    3'd5, 6'h2A);
  $display("PASS  [test 2] user=0x2A write+read @ 0x0100 (id=5)");

  // ----------------------------------------------------------
  // Test 3: read back test-1 address with different ar_user=0x3F
  //   Verifies that the USER field is driven by the requester,
  //   not stored from the previous transaction
  // ----------------------------------------------------------
  $display("\n--- Test 3: re-read 0x0080 with ar_user=0x3F, id=2 ---");
  burst_read4(32'h0000_0080,
    128'h1111_1111_1111_1111_1111_1111_1111_1111,
    128'h2222_2222_2222_2222_2222_2222_2222_2222,
    128'h3333_3333_3333_3333_3333_3333_3333_3333,
    128'h4444_4444_4444_4444_4444_4444_4444_4444,
    3'd2, 6'h3F);
  $display("PASS  [test 3] user=0x3F re-read @ 0x0080 (id=2)");

  $display("\nALL TESTS PASSED: user field correctly propagated AXI ↔ peripheral");
  $finish;
end

endmodule
