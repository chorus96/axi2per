`timescale 1ns/1ps
module tb_axi2per;
localparam int unsigned PER_ADDR_WIDTH = 32;
localparam int unsigned PER_DATA_WIDTH = 256;
localparam int unsigned AXI_ADDR_WIDTH = 32;
localparam int unsigned AXI_DATA_WIDTH = 128;
localparam int unsigned AXI_USER_WIDTH = 6;
localparam int unsigned AXI_ID_WIDTH   = 3;
localparam int unsigned BUFFER_DEPTH   = 2;
localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;
logic clk=0; always #5 clk=~clk;
logic rst_n; initial begin rst_n=0; repeat(4) @(posedge clk); rst_n=1; end
logic aw_valid; logic [AXI_ADDR_WIDTH-1:0] aw_addr; logic [7:0] aw_len; logic [2:0] aw_size; logic [1:0] aw_burst; logic [AXI_ID_WIDTH-1:0] aw_id; logic aw_ready;
logic ar_valid; logic [AXI_ADDR_WIDTH-1:0] ar_addr; logic [7:0] ar_len; logic [2:0] ar_size; logic [1:0] ar_burst; logic [AXI_ID_WIDTH-1:0] ar_id; logic ar_ready;
logic w_valid; logic [AXI_DATA_WIDTH-1:0] w_data; logic [AXI_STRB_WIDTH-1:0] w_strb; logic w_last; logic w_ready;
logic r_valid; logic [AXI_DATA_WIDTH-1:0] r_data; logic r_last; logic [AXI_ID_WIDTH-1:0] r_id; logic r_ready=1;
logic b_valid; logic [AXI_ID_WIDTH-1:0] b_id; logic b_ready=1;
logic per_req; logic [PER_ADDR_WIDTH-1:0] per_add; logic per_we_n; logic [PER_DATA_WIDTH-1:0] per_wdata; logic [PER_DATA_WIDTH/8-1:0] per_be; logic per_gnt; logic per_r_valid; logic per_r_opc; logic [PER_DATA_WIDTH-1:0] per_r_rdata; logic busy;
axi2per #(.PER_ADDR_WIDTH(PER_ADDR_WIDTH),.PER_DATA_WIDTH(PER_DATA_WIDTH),.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),.AXI_DATA_WIDTH(AXI_DATA_WIDTH),.AXI_USER_WIDTH(AXI_USER_WIDTH),.AXI_ID_WIDTH(AXI_ID_WIDTH),.BUFFER_DEPTH(BUFFER_DEPTH)) dut(
.clk_i(clk),.rst_ni(rst_n),.test_en_i(1'b0),
.axi_slave_aw_valid_i(aw_valid),.axi_slave_aw_addr_i(aw_addr),.axi_slave_aw_prot_i('0),.axi_slave_aw_region_i('0),.axi_slave_aw_len_i(aw_len),.axi_slave_aw_size_i(aw_size),.axi_slave_aw_burst_i(aw_burst),.axi_slave_aw_lock_i('0),.axi_slave_aw_cache_i('0),.axi_slave_aw_qos_i('0),.axi_slave_aw_id_i(aw_id),.axi_slave_aw_user_i('0),.axi_slave_aw_ready_o(aw_ready),
.axi_slave_ar_valid_i(ar_valid),.axi_slave_ar_addr_i(ar_addr),.axi_slave_ar_prot_i('0),.axi_slave_ar_region_i('0),.axi_slave_ar_len_i(ar_len),.axi_slave_ar_size_i(ar_size),.axi_slave_ar_burst_i(ar_burst),.axi_slave_ar_lock_i('0),.axi_slave_ar_cache_i('0),.axi_slave_ar_qos_i('0),.axi_slave_ar_id_i(ar_id),.axi_slave_ar_user_i('0),.axi_slave_ar_ready_o(ar_ready),
.axi_slave_w_valid_i(w_valid),.axi_slave_w_data_i(w_data),.axi_slave_w_strb_i(w_strb),.axi_slave_w_user_i('0),.axi_slave_w_last_i(w_last),.axi_slave_w_ready_o(w_ready),
.axi_slave_r_valid_o(r_valid),.axi_slave_r_data_o(r_data),.axi_slave_r_resp_o(),.axi_slave_r_last_o(r_last),.axi_slave_r_id_o(r_id),.axi_slave_r_user_o(),.axi_slave_r_ready_i(r_ready),
.axi_slave_b_valid_o(b_valid),.axi_slave_b_resp_o(),.axi_slave_b_id_o(b_id),.axi_slave_b_user_o(),.axi_slave_b_ready_i(b_ready),
.per_master_req_o(per_req),.per_master_add_o(per_add),.per_master_we_no(per_we_n),.per_master_wdata_o(per_wdata),.per_master_be_o(per_be),.per_master_gnt_i(per_gnt),
.per_master_r_valid_i(per_r_valid),.per_master_r_opc_i(per_r_opc),.per_master_r_rdata_i(per_r_rdata),.busy_o(busy));
per_slave_model #(.ADDR_WIDTH(PER_ADDR_WIDTH),.DATA_WIDTH(PER_DATA_WIDTH),.MEM_WORDS(256),.RESP_DELAY(1)) per(.clk_i(clk),.rst_ni(rst_n),.req_i(per_req),.add_i(per_add),.we_ni(per_we_n),.wdata_i(per_wdata),.be_i(per_be),.gnt_o(per_gnt),.r_valid_o(per_r_valid),.r_opc_o(per_r_opc),.r_rdata_o(per_r_rdata));

task burst_write2(input [31:0] addr,input [127:0] d0,d1,input [2:0] id); begin
 @(posedge clk); aw_valid<=1; aw_addr<=addr; aw_len<=8'd1; aw_size<=3'b100; aw_burst<=2'b01; aw_id<=id;
 wait(aw_ready); @(posedge clk); aw_valid<=0;
 w_valid<=1; w_strb<='1;
 w_data<=d0; w_last<=0; wait(w_ready); @(posedge clk);
 w_data<=d1; w_last<=1; wait(w_ready); @(posedge clk);
 w_valid<=0; w_last<=0;
 wait(b_valid); if(b_id!==id) $fatal(1,"BID mismatch");
end endtask

task burst_read2(input [31:0] addr,input [127:0] e0,e1,input [2:0] id); reg [127:0] got[0:1]; int i; begin
 @(posedge clk); ar_valid<=1; ar_addr<=addr; ar_len<=8'd1; ar_size<=3'b100; ar_burst<=2'b01; ar_id<=id; wait(ar_ready); @(posedge clk); ar_valid<=0;
 for(i=0;i<2;i++) begin
   @(posedge clk);
   while(!r_valid) @(posedge clk);
   got[i]=r_data;
   if(r_id!==id) $fatal(1,"RID mismatch");
 end
 if(got[0]!==e0 || got[1]!==e1) $fatal(1,"Read data mismatch");
end endtask

initial begin
 aw_valid=0;aw_addr=0;aw_len=0;aw_size=0;aw_burst=0;aw_id=0; ar_valid=0;ar_addr=0;ar_len=0;ar_size=0;ar_burst=0;ar_id=0; w_valid=0;w_data=0;w_strb=0;w_last=0;
 wait(rst_n);
 burst_write2(32'h0000_0040,128'h1111_1111_1111_1111_2222_2222_2222_2222,128'h3333_3333_3333_3333_4444_4444_4444_4444,3'd1);
 burst_read2(32'h0000_0040,128'h1111_1111_1111_1111_2222_2222_2222_2222,128'h3333_3333_3333_3333_4444_4444_4444_4444,3'd1);
 $display("PASS: 256/128 2-beat burst write/read");
 $finish;
end
endmodule
