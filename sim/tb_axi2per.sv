`timescale 1ns/1ps
// Test configuration: PER_DATA_WIDTH=256, AXI_DATA_WIDTH=64, 4-beat AXI bursts
// BEAT_RATIO = 256/64 = 4  →  one peripheral 256-bit word = four 64-bit AXI beats
module tb_axi2per;
localparam int unsigned PER_ADDR_WIDTH = 32;
localparam int unsigned PER_DATA_WIDTH = 256;
localparam int unsigned AXI_ADDR_WIDTH = 32;
localparam int unsigned AXI_DATA_WIDTH = 64;
localparam int unsigned AXI_USER_WIDTH = 6;
localparam int unsigned AXI_ID_WIDTH   = 3;
localparam int unsigned BUFFER_DEPTH   = 2;
localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;  // 8

// Clock & reset
logic clk=0;
// verilator lint_off BLKSEQ
always #5 clk=~clk;
// verilator lint_on BLKSEQ
logic rst_n;
initial begin rst_n=0; repeat(4) @(posedge clk); rst_n=1; end

// AXI signals
logic aw_valid; logic [AXI_ADDR_WIDTH-1:0] aw_addr; logic [7:0] aw_len;
logic [2:0] aw_size; logic [1:0] aw_burst; logic [AXI_ID_WIDTH-1:0] aw_id; logic aw_ready;
logic ar_valid; logic [AXI_ADDR_WIDTH-1:0] ar_addr; logic [7:0] ar_len;
logic [2:0] ar_size; logic [1:0] ar_burst; logic [AXI_ID_WIDTH-1:0] ar_id; logic ar_ready;
logic w_valid; logic [AXI_DATA_WIDTH-1:0] w_data; logic [AXI_STRB_WIDTH-1:0] w_strb;
logic w_last; logic w_ready;
logic r_valid; logic [AXI_DATA_WIDTH-1:0] r_data; logic r_last;
logic [AXI_ID_WIDTH-1:0] r_id; logic r_ready=1;
logic b_valid; logic [AXI_ID_WIDTH-1:0] b_id; logic b_ready=1;

// Peripheral signals
logic                      per_req;
logic [PER_ADDR_WIDTH-1:0] per_add;
logic                      per_we;
logic [PER_DATA_WIDTH-1:0] per_wdata;
logic [PER_DATA_WIDTH/8-1:0] per_be;
logic [4:0]                per_id;
logic [AXI_USER_WIDTH-1:0] per_user;
logic                      per_gnt;
logic                      per_r_valid;
logic                      per_r_opc;
logic [PER_DATA_WIDTH-1:0] per_r_rdata;
logic [4:0]                per_r_id;
logic [AXI_USER_WIDTH-1:0] per_r_user;
logic                      busy;

// DUT
axi2per #(
  .PER_ADDR_WIDTH(PER_ADDR_WIDTH), .PER_DATA_WIDTH(PER_DATA_WIDTH),
  .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH), .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
  .AXI_USER_WIDTH(AXI_USER_WIDTH), .AXI_ID_WIDTH(AXI_ID_WIDTH),
  .BUFFER_DEPTH(BUFFER_DEPTH)
) dut (
  .clk_i(clk), .rst_ni(rst_n), .test_en_i(1'b0),
  // AW
  .axi_slave_aw_valid_i(aw_valid), .axi_slave_aw_addr_i(aw_addr),
  .axi_slave_aw_prot_i('0), .axi_slave_aw_region_i('0),
  .axi_slave_aw_len_i(aw_len), .axi_slave_aw_size_i(aw_size),
  .axi_slave_aw_burst_i(aw_burst), .axi_slave_aw_lock_i('0),
  .axi_slave_aw_cache_i('0), .axi_slave_aw_qos_i('0),
  .axi_slave_aw_id_i(aw_id), .axi_slave_aw_user_i('0),
  .axi_slave_aw_ready_o(aw_ready),
  // AR
  .axi_slave_ar_valid_i(ar_valid), .axi_slave_ar_addr_i(ar_addr),
  .axi_slave_ar_prot_i('0), .axi_slave_ar_region_i('0),
  .axi_slave_ar_len_i(ar_len), .axi_slave_ar_size_i(ar_size),
  .axi_slave_ar_burst_i(ar_burst), .axi_slave_ar_lock_i('0),
  .axi_slave_ar_cache_i('0), .axi_slave_ar_qos_i('0),
  .axi_slave_ar_id_i(ar_id), .axi_slave_ar_user_i('0),
  .axi_slave_ar_ready_o(ar_ready),
  // W
  .axi_slave_w_valid_i(w_valid), .axi_slave_w_data_i(w_data),
  .axi_slave_w_strb_i(w_strb), .axi_slave_w_user_i('0),
  .axi_slave_w_last_i(w_last), .axi_slave_w_ready_o(w_ready),
  // R
  .axi_slave_r_valid_o(r_valid), .axi_slave_r_data_o(r_data),
  .axi_slave_r_resp_o(), .axi_slave_r_last_o(r_last),
  .axi_slave_r_id_o(r_id), .axi_slave_r_user_o(),
  .axi_slave_r_ready_i(r_ready),
  // B
  .axi_slave_b_valid_o(b_valid), .axi_slave_b_resp_o(),
  .axi_slave_b_id_o(b_id), .axi_slave_b_user_o(),
  .axi_slave_b_ready_i(b_ready),
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
// Task: 4-beat AXI write  (aw_len=3, aw_size=3'b011 = 8 bytes)
// Writes four consecutive 64-bit beats that together fill one
// 256-bit peripheral word at 'addr' (must be 32-byte aligned).
// ---------------------------------------------------------------
task burst_write4(
  input [31:0] addr,
  input [63:0] d0, d1, d2, d3,
  input [2:0]  id
);
begin
  @(posedge clk);
  aw_valid<=1; aw_addr<=addr; aw_len<=8'd3;
  aw_size<=3'b011; aw_burst<=2'b01; aw_id<=id;
  wait(aw_ready); @(posedge clk); aw_valid<=0;

  w_valid<=1; w_strb<='1;
  w_data<=d0; w_last<=0; wait(w_ready); @(posedge clk);
  w_data<=d1; w_last<=0; wait(w_ready); @(posedge clk);
  w_data<=d2; w_last<=0; wait(w_ready); @(posedge clk);
  w_data<=d3; w_last<=1; wait(w_ready); @(posedge clk);
  w_valid<=0; w_last<=0;

  wait(b_valid);
  if (b_id !== id) $fatal(1,"[WRITE] BID mismatch: got %0d expected %0d", b_id, id);
end
endtask

// ---------------------------------------------------------------
// Task: 4-beat AXI read  (ar_len=3, ar_size=3'b011 = 8 bytes)
// Reads four 64-bit beats and checks against expected values.
// ---------------------------------------------------------------
task burst_read4(
  input [31:0] addr,
  input [63:0] e0, e1, e2, e3,
  input [2:0]  id
);
  reg [63:0] got [0:3];
  int        i;
begin
  @(posedge clk);
  ar_valid<=1; ar_addr<=addr; ar_len<=8'd3;
  ar_size<=3'b011; ar_burst<=2'b01; ar_id<=id;
  wait(ar_ready); @(posedge clk); ar_valid<=0;

  for (i = 0; i < 4; i++) begin
    @(posedge clk);
    while (!r_valid) @(posedge clk);
    got[i] = r_data;
    if (r_id !== id)
      $fatal(1,"[READ beat %0d] RID mismatch: got %0d expected %0d", i, r_id, id);
  end

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
  aw_valid=0; aw_addr=0; aw_len=0; aw_size=0; aw_burst=0; aw_id=0;
  ar_valid=0; ar_addr=0; ar_len=0; ar_size=0; ar_burst=0; ar_id=0;
  w_valid=0;  w_data=0;  w_strb=0; w_last=0;

  wait(rst_n);

  // ----------------------------------------------------------
  // Test 1: write 256-bit word at 0x0040, read it back
  //   beat0 → bits  63:0   = 64'h1111_1111_1111_1111
  //   beat1 → bits 127:64  = 64'h2222_2222_2222_2222
  //   beat2 → bits 191:128 = 64'h3333_3333_3333_3333
  //   beat3 → bits 255:192 = 64'h4444_4444_4444_4444
  // ----------------------------------------------------------
  burst_write4(32'h0000_0040,
               64'h1111_1111_1111_1111,
               64'h2222_2222_2222_2222,
               64'h3333_3333_3333_3333,
               64'h4444_4444_4444_4444,
               3'd1);

  burst_read4(32'h0000_0040,
              64'h1111_1111_1111_1111,
              64'h2222_2222_2222_2222,
              64'h3333_3333_3333_3333,
              64'h4444_4444_4444_4444,
              3'd1);
  $display("PASS  [test 1] 256-bit / 64-bit 4-beat burst write+read @ 0x0040");

  // ----------------------------------------------------------
  // Test 2: different address (0x0080) and different ID
  //   Verifies independent memory location and ID passthrough
  // ----------------------------------------------------------
  burst_write4(32'h0000_0080,
               64'hAAAA_BBBB_CCCC_DDDD,
               64'hEEEE_FFFF_0000_1111,
               64'h2222_3333_4444_5555,
               64'h6666_7777_8888_9999,
               3'd5);

  burst_read4(32'h0000_0080,
              64'hAAAA_BBBB_CCCC_DDDD,
              64'hEEEE_FFFF_0000_1111,
              64'h2222_3333_4444_5555,
              64'h6666_7777_8888_9999,
              3'd5);
  $display("PASS  [test 2] 256-bit / 64-bit 4-beat burst write+read @ 0x0080 (id=5)");

  // ----------------------------------------------------------
  // Test 3: verify test-1 location is untouched after test-2
  // ----------------------------------------------------------
  burst_read4(32'h0000_0040,
              64'h1111_1111_1111_1111,
              64'h2222_2222_2222_2222,
              64'h3333_3333_3333_3333,
              64'h4444_4444_4444_4444,
              3'd2);
  $display("PASS  [test 3] Re-read @ 0x0040 unchanged after write to 0x0080");

  $display("ALL TESTS PASSED: PER_DATA_WIDTH=256 / AXI_DATA_WIDTH=64 / 4-beat burst");
  $finish;
end

endmodule
