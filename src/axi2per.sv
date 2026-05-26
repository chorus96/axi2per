// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Davide Rossi <davide.rossi@unibo.it>
//
// AMD Vivado IP Packager compatible:
//   - AXI4 slave ports renamed to Vivado convention  (s_axi_*)
//   - Clock/reset renamed to AXI convention          (aclk / aresetn)
//   - X_INTERFACE_INFO / X_INTERFACE_PARAMETER       (Vivado interface auto-inference)
//   - parameter integer                              (Vivado IP GUI parameter type)

module axi2per
#(
   parameter integer PER_DATA_WIDTH = 256,
   parameter integer AXI_ADDR_WIDTH = 32,
   parameter integer AXI_DATA_WIDTH = 64,
   parameter integer AXI_USER_WIDTH = 6,
   parameter integer AXI_ID_WIDTH   = 3,
   parameter integer PER_ID_WIDTH   = 2**AXI_ID_WIDTH,  // one-hot: 2^AXI_ID_WIDTH bits
   parameter integer BUFFER_DEPTH   = 2,
   parameter integer AXI_STRB_WIDTH = AXI_DATA_WIDTH/8
)
(
   // ── Clock ────────────────────────────────────────────────────────────────────
   (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 ACLK CLK" *)
   (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET ARESETN, FREQ_HZ 100000000, PHASE 0.0" *)
   input  logic                      aclk,

   // ── Reset (active-low) ───────────────────────────────────────────────────────
   (* X_INTERFACE_INFO      = "xilinx.com:signal:reset:1.0 ARESETN RST" *)
   (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
   input  logic                      aresetn,

   // Non-AXI control
   input  logic                      test_en_i,

   // ── AXI4 Slave – Write Address Channel (AW) ──────────────────────────────────
   (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI, DATA_WIDTH 64, PROTOCOL AXI4, FREQ_HZ 100000000, ID_WIDTH 3, ADDR_WIDTH 32, AWUSER_WIDTH 6, ARUSER_WIDTH 6, RUSER_WIDTH 6, WUSER_WIDTH 0, BUSER_WIDTH 6, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 1, HAS_REGION 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, READ_WRITE_MODE READ_WRITE, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256" *)
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
   input  logic                      s_axi_awvalid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
   input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
   input  logic [2:0]                s_axi_awprot,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREGION" *)
   input  logic [3:0]                s_axi_awregion,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWLEN" *)
   input  logic [7:0]                s_axi_awlen,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWSIZE" *)
   input  logic [2:0]                s_axi_awsize,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWBURST" *)
   input  logic [1:0]                s_axi_awburst,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWLOCK" *)
   input  logic                      s_axi_awlock,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWCACHE" *)
   input  logic [3:0]                s_axi_awcache,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWQOS" *)
   input  logic [3:0]                s_axi_awqos,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWID" *)
   input  logic [AXI_ID_WIDTH-1:0]   s_axi_awid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWUSER" *)
   input  logic [AXI_USER_WIDTH-1:0] s_axi_awuser,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
   output logic                      s_axi_awready,

   // ── AXI4 Slave – Read Address Channel (AR) ───────────────────────────────────
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
   input  logic                      s_axi_arvalid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
   input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
   input  logic [2:0]                s_axi_arprot,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREGION" *)
   input  logic [3:0]                s_axi_arregion,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARLEN" *)
   input  logic [7:0]                s_axi_arlen,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARSIZE" *)
   input  logic [2:0]                s_axi_arsize,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARBURST" *)
   input  logic [1:0]                s_axi_arburst,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARLOCK" *)
   input  logic                      s_axi_arlock,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARCACHE" *)
   input  logic [3:0]                s_axi_arcache,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARQOS" *)
   input  logic [3:0]                s_axi_arqos,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARID" *)
   input  logic [AXI_ID_WIDTH-1:0]   s_axi_arid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARUSER" *)
   input  logic [AXI_USER_WIDTH-1:0] s_axi_aruser,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
   output logic                      s_axi_arready,

   // ── AXI4 Slave – Write Data Channel (W) ──────────────────────────────────────
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
   input  logic                      s_axi_wvalid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
   input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
   input  logic [AXI_STRB_WIDTH-1:0] s_axi_wstrb,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WUSER" *)
   input  logic [AXI_USER_WIDTH-1:0] s_axi_wuser,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WLAST" *)
   input  logic                      s_axi_wlast,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
   output logic                      s_axi_wready,

   // ── AXI4 Slave – Read Data Channel (R) ───────────────────────────────────────
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
   output logic                      s_axi_rvalid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
   output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
   output logic [1:0]                s_axi_rresp,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RLAST" *)
   output logic                      s_axi_rlast,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RID" *)
   output logic [AXI_ID_WIDTH-1:0]   s_axi_rid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RUSER" *)
   output logic [AXI_USER_WIDTH-1:0] s_axi_ruser,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
   input  logic                      s_axi_rready,

   // ── AXI4 Slave – Write Response Channel (B) ──────────────────────────────────
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
   output logic                      s_axi_bvalid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
   output logic [1:0]                s_axi_bresp,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BID" *)
   output logic [AXI_ID_WIDTH-1:0]   s_axi_bid,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BUSER" *)
   output logic [AXI_USER_WIDTH-1:0] s_axi_buser,
   (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
   input  logic                      s_axi_bready,

   // ── PULP Peripheral Interconnect Master (custom interface) ───────────────────
   // REQUEST CHANNEL
   output logic                        per_master_req_o,
   output logic [PER_ADDR_WIDTH-1:0]   per_master_add_o,
   output logic                        per_master_we_o,      // 1=WRITE, 0=READ (PULP convention)
   output logic [PER_DATA_WIDTH-1:0]   per_master_wdata_o,
   output logic [PER_DATA_WIDTH/8-1:0] per_master_be_o,
   output logic [PER_ID_WIDTH-1:0]     per_master_id_o,      // one-hot encoded
   output logic [AXI_USER_WIDTH-1:0]   per_master_user_o,
   input  logic                        per_master_gnt_i,

   // RESPONSE CHANNEL
   input  logic                        per_master_r_valid_i,
   input  logic                        per_master_r_opc_i,
   input  logic [PER_DATA_WIDTH-1:0]   per_master_r_rdata_i,
   input  logic [PER_ID_WIDTH-1:0]     per_master_r_id_i,
   input  logic [AXI_USER_WIDTH-1:0]   per_master_r_user_i,

   // BUSY SIGNAL
   output logic                        busy_o
);

   // ── PER_ADDR_WIDTH is always equal to AXI_ADDR_WIDTH ────────────────────────
   localparam integer PER_ADDR_WIDTH = AXI_ADDR_WIDTH;

   // ── Internal signal declarations ─────────────────────────────────────────────
   logic                              s_aw_valid;
   logic [AXI_ADDR_WIDTH-1:0]         s_aw_addr;
   logic [2:0]                        s_aw_prot;
   logic [3:0]                        s_aw_region;
   logic [7:0]                        s_aw_len;
   logic [2:0]                        s_aw_size;
   logic [1:0]                        s_aw_burst;
   logic                              s_aw_lock;
   logic [3:0]                        s_aw_cache;
   logic [3:0]                        s_aw_qos;
   logic [AXI_ID_WIDTH-1:0]           s_aw_id;
   logic [AXI_USER_WIDTH-1:0]         s_aw_user;
   logic                              s_aw_ready;

   logic                              s_ar_valid;
   logic [AXI_ADDR_WIDTH-1:0]         s_ar_addr;
   logic [2:0]                        s_ar_prot;
   logic [3:0]                        s_ar_region;
   logic [7:0]                        s_ar_len;
   logic [2:0]                        s_ar_size;
   logic [1:0]                        s_ar_burst;
   logic                              s_ar_lock;
   logic [3:0]                        s_ar_cache;
   logic [3:0]                        s_ar_qos;
   logic [AXI_ID_WIDTH-1:0]           s_ar_id;
   logic [AXI_USER_WIDTH-1:0]         s_ar_user;
   logic                              s_ar_ready;

   logic                              s_w_valid;
   logic [AXI_DATA_WIDTH-1:0]         s_w_data;
   logic [AXI_STRB_WIDTH-1:0]         s_w_strb;
   logic [AXI_USER_WIDTH-1:0]         s_w_user;
   logic                              s_w_last;
   logic                              s_w_ready;

   logic                              s_r_valid;
   logic [AXI_DATA_WIDTH-1:0]         s_r_data;
   logic [1:0]                        s_r_resp;
   logic                              s_r_last;
   logic [AXI_ID_WIDTH-1:0]           s_r_id;
   logic [AXI_USER_WIDTH-1:0]         s_r_user;
   logic                              s_r_ready;

   logic                              s_b_valid;
   logic [1:0]                        s_b_resp;
   logic [AXI_ID_WIDTH-1:0]           s_b_id;
   logic [AXI_USER_WIDTH-1:0]         s_b_user;
   logic                              s_b_ready;

   logic                              s_trans_req;
   logic                              s_trans_we;
   logic [AXI_ID_WIDTH-1:0]           s_trans_id;
   logic [AXI_ADDR_WIDTH-1:0]         s_trans_add;
   logic [7:0]                        s_trans_len;
   logic                              s_trans_r_valid;

   // ── AXI2PER REQUEST CHANNEL ──────────────────────────────────────────────────
   axi2per_req_channel
   #(
      .PER_ID_WIDTH          ( PER_ID_WIDTH        ),
      .PER_DATA_WIDTH        ( PER_DATA_WIDTH      ),
      .AXI_ADDR_WIDTH        ( AXI_ADDR_WIDTH      ),
      .AXI_DATA_WIDTH        ( AXI_DATA_WIDTH      ),
      .AXI_USER_WIDTH        ( AXI_USER_WIDTH      ),
      .AXI_ID_WIDTH          ( AXI_ID_WIDTH        )
   )
   req_channel_i
   (
      .clk_i                 ( aclk                ),
      .rst_ni                ( aresetn             ),

      .axi_slave_aw_valid_i  ( s_aw_valid          ),
      .axi_slave_aw_addr_i   ( s_aw_addr           ),
      .axi_slave_aw_prot_i   ( s_aw_prot           ),
      .axi_slave_aw_region_i ( s_aw_region         ),
      .axi_slave_aw_len_i    ( s_aw_len            ),
      .axi_slave_aw_size_i   ( s_aw_size           ),
      .axi_slave_aw_burst_i  ( s_aw_burst          ),
      .axi_slave_aw_lock_i   ( s_aw_lock           ),
      .axi_slave_aw_cache_i  ( s_aw_cache          ),
      .axi_slave_aw_qos_i    ( s_aw_qos            ),
      .axi_slave_aw_id_i     ( s_aw_id             ),
      .axi_slave_aw_user_i   ( s_aw_user           ),
      .axi_slave_aw_ready_o  ( s_aw_ready          ),

      .axi_slave_ar_valid_i  ( s_ar_valid          ),
      .axi_slave_ar_addr_i   ( s_ar_addr           ),
      .axi_slave_ar_prot_i   ( s_ar_prot           ),
      .axi_slave_ar_region_i ( s_ar_region         ),
      .axi_slave_ar_len_i    ( s_ar_len            ),
      .axi_slave_ar_size_i   ( s_ar_size           ),
      .axi_slave_ar_burst_i  ( s_ar_burst          ),
      .axi_slave_ar_lock_i   ( s_ar_lock           ),
      .axi_slave_ar_cache_i  ( s_ar_cache          ),
      .axi_slave_ar_qos_i    ( s_ar_qos            ),
      .axi_slave_ar_id_i     ( s_ar_id             ),
      .axi_slave_ar_user_i   ( s_ar_user           ),
      .axi_slave_ar_ready_o  ( s_ar_ready          ),

      .axi_slave_w_valid_i   ( s_w_valid           ),
      .axi_slave_w_data_i    ( s_w_data            ),
      .axi_slave_w_strb_i    ( s_w_strb            ),
      .axi_slave_w_user_i    ( s_w_user            ),
      .axi_slave_w_last_i    ( s_w_last            ),
      .axi_slave_w_ready_o   ( s_w_ready           ),

      .per_master_req_o      ( per_master_req_o    ),
      .per_master_add_o      ( per_master_add_o    ),
      .per_master_we_o       ( per_master_we_o     ),
      .per_master_wdata_o    ( per_master_wdata_o  ),
      .per_master_be_o       ( per_master_be_o     ),
      .per_master_id_o       ( per_master_id_o     ),
      .per_master_user_o     ( per_master_user_o   ),
      .per_master_gnt_i      ( per_master_gnt_i    ),

      .trans_req_o           ( s_trans_req         ),
      .trans_we_o            ( s_trans_we          ),
      .trans_id_o            ( s_trans_id          ),
      .trans_add_o           ( s_trans_add         ),
      .trans_len_o           ( s_trans_len         ),
      .trans_r_valid_i       ( s_trans_r_valid     ),

      .busy_o                ( busy_o              )
   );

   // ── AXI2PER RESPONSE CHANNEL ─────────────────────────────────────────────────
   axi2per_res_channel
   #(
      .PER_ID_WIDTH         ( PER_ID_WIDTH         ),
      .PER_DATA_WIDTH       ( PER_DATA_WIDTH       ),
      .AXI_ADDR_WIDTH       ( AXI_ADDR_WIDTH       ),
      .AXI_DATA_WIDTH       ( AXI_DATA_WIDTH       ),
      .AXI_USER_WIDTH       ( AXI_USER_WIDTH       ),
      .AXI_ID_WIDTH         ( AXI_ID_WIDTH         )
   )
   res_channel_i
   (
      .clk_i                ( aclk                 ),
      .rst_ni               ( aresetn              ),

      .axi_slave_r_valid_o  ( s_r_valid            ),
      .axi_slave_r_data_o   ( s_r_data             ),
      .axi_slave_r_resp_o   ( s_r_resp             ),
      .axi_slave_r_last_o   ( s_r_last             ),
      .axi_slave_r_id_o     ( s_r_id               ),
      .axi_slave_r_user_o   ( s_r_user             ),
      .axi_slave_r_ready_i  ( s_r_ready            ),

      .axi_slave_b_valid_o  ( s_b_valid            ),
      .axi_slave_b_resp_o   ( s_b_resp             ),
      .axi_slave_b_id_o     ( s_b_id               ),
      .axi_slave_b_user_o   ( s_b_user             ),
      .axi_slave_b_ready_i  ( s_b_ready            ),

      .per_master_r_valid_i ( per_master_r_valid_i ),
      .per_master_r_opc_i   ( per_master_r_opc_i   ),
      .per_master_r_rdata_i ( per_master_r_rdata_i ),
      .per_master_r_id_i    ( per_master_r_id_i    ),
      .per_master_r_user_i  ( per_master_r_user_i  ),

      .trans_req_i          ( s_trans_req          ),
      .trans_we_i           ( s_trans_we           ),
      .trans_id_i           ( s_trans_id           ),
      .trans_add_i          ( s_trans_add          ),
      .trans_len_i          ( s_trans_len          ),
      .trans_r_valid_o      ( s_trans_r_valid      )
   );

   // ── AXI WRITE ADDRESS CHANNEL BUFFER ─────────────────────────────────────────
   axi_aw_buffer
   #(
      .ID_WIDTH        ( AXI_ID_WIDTH           ),
      .ADDR_WIDTH      ( AXI_ADDR_WIDTH         ),
      .USER_WIDTH      ( AXI_USER_WIDTH         ),
      .BUFFER_DEPTH    ( BUFFER_DEPTH           )
   )
   aw_buffer_i
   (
      .clk_i           ( aclk                   ),
      .rst_ni          ( aresetn                ),
      .test_en_i       ( test_en_i              ),

      .slave_valid_i   ( s_axi_awvalid          ),
      .slave_addr_i    ( s_axi_awaddr           ),
      .slave_prot_i    ( s_axi_awprot           ),
      .slave_region_i  ( s_axi_awregion         ),
      .slave_len_i     ( s_axi_awlen            ),
      .slave_size_i    ( s_axi_awsize           ),
      .slave_burst_i   ( s_axi_awburst          ),
      .slave_lock_i    ( s_axi_awlock           ),
      .slave_cache_i   ( s_axi_awcache          ),
      .slave_qos_i     ( s_axi_awqos            ),
      .slave_id_i      ( s_axi_awid             ),
      .slave_user_i    ( s_axi_awuser           ),
      .slave_ready_o   ( s_axi_awready          ),

      .master_valid_o  ( s_aw_valid             ),
      .master_addr_o   ( s_aw_addr              ),
      .master_prot_o   ( s_aw_prot              ),
      .master_region_o ( s_aw_region            ),
      .master_len_o    ( s_aw_len               ),
      .master_size_o   ( s_aw_size              ),
      .master_burst_o  ( s_aw_burst             ),
      .master_lock_o   ( s_aw_lock              ),
      .master_cache_o  ( s_aw_cache             ),
      .master_qos_o    ( s_aw_qos               ),
      .master_id_o     ( s_aw_id                ),
      .master_user_o   ( s_aw_user              ),
      .master_ready_i  ( s_aw_ready             )
   );

   // ── AXI READ ADDRESS CHANNEL BUFFER ──────────────────────────────────────────
   axi_ar_buffer
   #(
      .ID_WIDTH        ( AXI_ID_WIDTH       ),
      .ADDR_WIDTH      ( AXI_ADDR_WIDTH     ),
      .USER_WIDTH      ( AXI_USER_WIDTH     ),
      .BUFFER_DEPTH    ( BUFFER_DEPTH       )
   )
   ar_buffer_i
   (
      .clk_i            ( aclk                    ),
      .rst_ni           ( aresetn                 ),
      .test_en_i        ( test_en_i               ),

      .slave_valid_i    ( s_axi_arvalid           ),
      .slave_addr_i     ( s_axi_araddr            ),
      .slave_prot_i     ( s_axi_arprot            ),
      .slave_region_i   ( s_axi_arregion          ),
      .slave_len_i      ( s_axi_arlen             ),
      .slave_size_i     ( s_axi_arsize            ),
      .slave_burst_i    ( s_axi_arburst           ),
      .slave_lock_i     ( s_axi_arlock            ),
      .slave_cache_i    ( s_axi_arcache           ),
      .slave_qos_i      ( s_axi_arqos             ),
      .slave_id_i       ( s_axi_arid              ),
      .slave_user_i     ( s_axi_aruser            ),
      .slave_ready_o    ( s_axi_arready           ),

      .master_valid_o   ( s_ar_valid              ),
      .master_addr_o    ( s_ar_addr               ),
      .master_prot_o    ( s_ar_prot               ),
      .master_region_o  ( s_ar_region             ),
      .master_len_o     ( s_ar_len                ),
      .master_size_o    ( s_ar_size               ),
      .master_burst_o   ( s_ar_burst              ),
      .master_lock_o    ( s_ar_lock               ),
      .master_cache_o   ( s_ar_cache              ),
      .master_qos_o     ( s_ar_qos                ),
      .master_id_o      ( s_ar_id                 ),
      .master_user_o    ( s_ar_user               ),
      .master_ready_i   ( s_ar_ready              )
   );

   // ── WRITE DATA CHANNEL BUFFER ─────────────────────────────────────────────────
   axi_w_buffer
   #(
      .DATA_WIDTH    ( AXI_DATA_WIDTH  ),
      .USER_WIDTH    ( AXI_USER_WIDTH  ),
      .BUFFER_DEPTH  ( BUFFER_DEPTH    )
   )
   w_buffer_i
   (
      .clk_i           ( aclk                 ),
      .rst_ni          ( aresetn              ),
      .test_en_i       ( test_en_i            ),

      .slave_valid_i   ( s_axi_wvalid         ),
      .slave_data_i    ( s_axi_wdata          ),
      .slave_strb_i    ( s_axi_wstrb          ),
      .slave_user_i    ( s_axi_wuser          ),
      .slave_last_i    ( s_axi_wlast          ),
      .slave_ready_o   ( s_axi_wready         ),

      .master_valid_o  ( s_w_valid            ),
      .master_data_o   ( s_w_data             ),
      .master_strb_o   ( s_w_strb             ),
      .master_user_o   ( s_w_user             ),
      .master_last_o   ( s_w_last             ),
      .master_ready_i  ( s_w_ready            )
   );

   // ── READ DATA CHANNEL BUFFER ──────────────────────────────────────────────────
   axi_r_buffer
   #(
      .ID_WIDTH      ( AXI_ID_WIDTH    ),
      .DATA_WIDTH    ( AXI_DATA_WIDTH  ),
      .USER_WIDTH    ( AXI_USER_WIDTH  ),
      .BUFFER_DEPTH  ( BUFFER_DEPTH    )
   )
   r_buffer_i
   (
      .clk_i           ( aclk                 ),
      .rst_ni          ( aresetn              ),
      .test_en_i       ( test_en_i            ),

      .slave_valid_i   ( s_r_valid            ),
      .slave_data_i    ( s_r_data             ),
      .slave_resp_i    ( s_r_resp             ),
      .slave_user_i    ( s_r_user             ),
      .slave_id_i      ( s_r_id               ),
      .slave_last_i    ( s_r_last             ),
      .slave_ready_o   ( s_r_ready            ),

      .master_valid_o  ( s_axi_rvalid         ),
      .master_data_o   ( s_axi_rdata          ),
      .master_resp_o   ( s_axi_rresp          ),
      .master_user_o   ( s_axi_ruser          ),
      .master_id_o     ( s_axi_rid            ),
      .master_last_o   ( s_axi_rlast          ),
      .master_ready_i  ( s_axi_rready         )
   );

   // ── WRITE RESPONSE CHANNEL BUFFER ────────────────────────────────────────────
   axi_b_buffer
   #(
      .ID_WIDTH        ( AXI_ID_WIDTH         ),
      .USER_WIDTH      ( AXI_USER_WIDTH       ),
      .BUFFER_DEPTH    ( BUFFER_DEPTH         )
   )
   b_buffer_i
   (
      .clk_i           ( aclk                 ),
      .rst_ni          ( aresetn              ),
      .test_en_i       ( test_en_i            ),

      .slave_valid_i   ( s_b_valid            ),
      .slave_resp_i    ( s_b_resp             ),
      .slave_id_i      ( s_b_id               ),
      .slave_user_i    ( s_b_user             ),
      .slave_ready_o   ( s_b_ready            ),

      .master_valid_o  ( s_axi_bvalid         ),
      .master_resp_o   ( s_axi_bresp          ),
      .master_id_o     ( s_axi_bid            ),
      .master_user_o   ( s_axi_buser          ),
      .master_ready_i  ( s_axi_bready         )
   );

endmodule
