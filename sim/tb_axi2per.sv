// Testbench for axi2per
//
// Topology:
//   [AXI4 Master (TB)] --> [axi2per DUT] --> [per_slave_model]
//
// Test cases:
//   TC1: Single AXI write  to lower-word address (addr[2]=0)
//   TC2: Single AXI write  to upper-word address (addr[2]=1)
//   TC3: Single AXI read   from lower-word address
//   TC4: Single AXI read   from upper-word address
//   TC5: Consecutive write-then-read (data integrity check)
//   TC6: Multiple back-to-back reads

`timescale 1ns/1ps

module tb_axi2per;

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    localparam int unsigned PER_ADDR_WIDTH = 32;
    localparam int unsigned AXI_ADDR_WIDTH = 32;
    localparam int unsigned AXI_DATA_WIDTH = 64;
    localparam int unsigned AXI_USER_WIDTH = 6;
    localparam int unsigned AXI_ID_WIDTH   = 3;
    localparam int unsigned BUFFER_DEPTH   = 2;
    localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

    localparam int unsigned MEM_WORDS  = 256;
    localparam real         CLK_PERIOD = 10.0; // ns

    // -----------------------------------------------------------------------
    // Clock & reset
    // -----------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    // verilator lint_off BLKSEQ
    always #(CLK_PERIOD/2) clk = ~clk;
    // verilator lint_on BLKSEQ

    initial begin
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        #1;
        rst_n = 1'b1;
    end

    // -----------------------------------------------------------------------
    // AXI4 signals (TB -> DUT)
    // -----------------------------------------------------------------------
    // Write Address Channel
    logic                      aw_valid;
    logic [AXI_ADDR_WIDTH-1:0] aw_addr;
    logic [2:0]                aw_prot;
    logic [3:0]                aw_region;
    logic [7:0]                aw_len;
    logic [2:0]                aw_size;
    logic [1:0]                aw_burst;
    logic                      aw_lock;
    logic [3:0]                aw_cache;
    logic [3:0]                aw_qos;
    logic [AXI_ID_WIDTH-1:0]   aw_id;
    logic [AXI_USER_WIDTH-1:0] aw_user;
    logic                      aw_ready;

    // Read Address Channel
    logic                      ar_valid;
    logic [AXI_ADDR_WIDTH-1:0] ar_addr;
    logic [2:0]                ar_prot;
    logic [3:0]                ar_region;
    logic [7:0]                ar_len;
    logic [2:0]                ar_size;
    logic [1:0]                ar_burst;
    logic                      ar_lock;
    logic [3:0]                ar_cache;
    logic [3:0]                ar_qos;
    logic [AXI_ID_WIDTH-1:0]   ar_id;
    logic [AXI_USER_WIDTH-1:0] ar_user;
    logic                      ar_ready;

    // Write Data Channel
    logic                      w_valid;
    logic [AXI_DATA_WIDTH-1:0] w_data;
    logic [AXI_STRB_WIDTH-1:0] w_strb;
    logic [AXI_USER_WIDTH-1:0] w_user;
    logic                      w_last;
    logic                      w_ready;

    // Read Data Channel
    logic                      r_valid;
    logic [AXI_DATA_WIDTH-1:0] r_data;
    logic [1:0]                r_resp;
    logic                      r_last;
    logic [AXI_ID_WIDTH-1:0]   r_id;
    logic [AXI_USER_WIDTH-1:0] r_user;
    logic                      r_ready;

    // Write Response Channel
    logic                      b_valid;
    logic [1:0]                b_resp;
    logic [AXI_ID_WIDTH-1:0]   b_id;
    logic [AXI_USER_WIDTH-1:0] b_user;
    logic                      b_ready;

    // -----------------------------------------------------------------------
    // Peripheral Interconnect signals (DUT -> per_slave_model)
    // -----------------------------------------------------------------------
    logic                      per_req;
    logic [PER_ADDR_WIDTH-1:0] per_add;
    logic                      per_we_n;   // 1=READ, 0=WRITE
    logic [31:0]               per_wdata;
    logic [3:0]                per_be;
    logic                      per_gnt;
    logic                      per_r_valid;
    logic                      per_r_opc;
    logic [31:0]               per_r_rdata;
    logic                      busy;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    axi2per #(
        .PER_ADDR_WIDTH ( PER_ADDR_WIDTH ),
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH   ),
        .BUFFER_DEPTH   ( BUFFER_DEPTH   )
    ) dut (
        .clk_i                  ( clk         ),
        .rst_ni                 ( rst_n        ),
        .test_en_i              ( 1'b0         ),

        .axi_slave_aw_valid_i   ( aw_valid     ),
        .axi_slave_aw_addr_i    ( aw_addr      ),
        .axi_slave_aw_prot_i    ( aw_prot      ),
        .axi_slave_aw_region_i  ( aw_region    ),
        .axi_slave_aw_len_i     ( aw_len       ),
        .axi_slave_aw_size_i    ( aw_size      ),
        .axi_slave_aw_burst_i   ( aw_burst     ),
        .axi_slave_aw_lock_i    ( aw_lock      ),
        .axi_slave_aw_cache_i   ( aw_cache     ),
        .axi_slave_aw_qos_i     ( aw_qos       ),
        .axi_slave_aw_id_i      ( aw_id        ),
        .axi_slave_aw_user_i    ( aw_user      ),
        .axi_slave_aw_ready_o   ( aw_ready     ),

        .axi_slave_ar_valid_i   ( ar_valid     ),
        .axi_slave_ar_addr_i    ( ar_addr      ),
        .axi_slave_ar_prot_i    ( ar_prot      ),
        .axi_slave_ar_region_i  ( ar_region    ),
        .axi_slave_ar_len_i     ( ar_len       ),
        .axi_slave_ar_size_i    ( ar_size      ),
        .axi_slave_ar_burst_i   ( ar_burst     ),
        .axi_slave_ar_lock_i    ( ar_lock      ),
        .axi_slave_ar_cache_i   ( ar_cache     ),
        .axi_slave_ar_qos_i     ( ar_qos       ),
        .axi_slave_ar_id_i      ( ar_id        ),
        .axi_slave_ar_user_i    ( ar_user      ),
        .axi_slave_ar_ready_o   ( ar_ready     ),

        .axi_slave_w_valid_i    ( w_valid      ),
        .axi_slave_w_data_i     ( w_data       ),
        .axi_slave_w_strb_i     ( w_strb       ),
        .axi_slave_w_user_i     ( w_user       ),
        .axi_slave_w_last_i     ( w_last       ),
        .axi_slave_w_ready_o    ( w_ready      ),

        .axi_slave_r_valid_o    ( r_valid      ),
        .axi_slave_r_data_o     ( r_data       ),
        .axi_slave_r_resp_o     ( r_resp       ),
        .axi_slave_r_last_o     ( r_last       ),
        .axi_slave_r_id_o       ( r_id         ),
        .axi_slave_r_user_o     ( r_user       ),
        .axi_slave_r_ready_i    ( r_ready      ),

        .axi_slave_b_valid_o    ( b_valid      ),
        .axi_slave_b_resp_o     ( b_resp       ),
        .axi_slave_b_id_o       ( b_id         ),
        .axi_slave_b_user_o     ( b_user       ),
        .axi_slave_b_ready_i    ( b_ready      ),

        .per_master_req_o       ( per_req      ),
        .per_master_add_o       ( per_add      ),
        .per_master_we_no       ( per_we_n     ),
        .per_master_wdata_o     ( per_wdata    ),
        .per_master_be_o        ( per_be       ),
        .per_master_gnt_i       ( per_gnt      ),

        .per_master_r_valid_i   ( per_r_valid  ),
        .per_master_r_opc_i     ( per_r_opc    ),
        .per_master_r_rdata_i   ( per_r_rdata  ),

        .busy_o                 ( busy         )
    );

    // -----------------------------------------------------------------------
    // Peripheral slave model instantiation
    // -----------------------------------------------------------------------
    per_slave_model #(
        .ADDR_WIDTH ( PER_ADDR_WIDTH ),
        .MEM_WORDS  ( MEM_WORDS      ),
        .RESP_DELAY ( 1              )
    ) per_slave (
        .clk_i      ( clk         ),
        .rst_ni     ( rst_n        ),
        .req_i      ( per_req      ),
        .add_i      ( per_add      ),
        .we_ni      ( per_we_n     ),
        .wdata_i    ( per_wdata    ),
        .be_i       ( per_be       ),
        .gnt_o      ( per_gnt      ),
        .r_valid_o  ( per_r_valid  ),
        .r_opc_o    ( per_r_opc    ),
        .r_rdata_o  ( per_r_rdata  )
    );

    // -----------------------------------------------------------------------
    // Default / idle values
    // -----------------------------------------------------------------------
    initial begin
        aw_valid  = 0; aw_addr  = '0; aw_prot  = '0; aw_region = '0;
        aw_len    = '0; aw_size = 3'b010; aw_burst = 2'b01; aw_lock = 0;
        aw_cache  = '0; aw_qos  = '0; aw_id   = '0; aw_user  = '0;

        ar_valid  = 0; ar_addr  = '0; ar_prot  = '0; ar_region = '0;
        ar_len    = '0; ar_size = 3'b010; ar_burst = 2'b01; ar_lock = 0;
        ar_cache  = '0; ar_qos  = '0; ar_id   = '0; ar_user  = '0;

        w_valid   = 0; w_data  = '0; w_strb  = '0; w_user  = '0; w_last = 0;
        r_ready   = 1;
        b_ready   = 1;
    end

    // -----------------------------------------------------------------------
    // Task: AXI4 single-beat write
    //   addr  : byte address (only addr[2] matters for 32→64-bit mapping)
    //   data  : 64-bit write data (only relevant 32 bits used)
    //   strb  : 8-bit byte strobe
    //   id    : AXI transaction ID
    // -----------------------------------------------------------------------
    task automatic axi_write(
        input logic [AXI_ADDR_WIDTH-1:0] addr,
        input logic [AXI_DATA_WIDTH-1:0] data,
        input logic [AXI_STRB_WIDTH-1:0] strb,
        input logic [AXI_ID_WIDTH-1:0]   id
    );
        // Drive AW and W channels simultaneously
        @(posedge clk); #1;
        aw_valid = 1'b1;
        aw_addr  = addr;
        aw_id    = id;
        aw_len   = 8'h00;   // single beat
        aw_size  = 3'b011;  // 8 bytes
        aw_burst = 2'b01;   // INCR

        w_valid  = 1'b1;
        w_data   = data;
        w_strb   = strb;
        w_last   = 1'b1;

        // Wait for AW handshake
        fork
            begin
                @(posedge clk iff aw_ready); #1;
                aw_valid = 1'b0;
            end
            begin
                @(posedge clk iff w_ready); #1;
                w_valid = 1'b0;
                w_last  = 1'b0;
            end
        join

        // Wait for write response (B channel)
        b_ready = 1'b1;
        @(posedge clk iff b_valid);
        $display("[TB] WRITE done: addr=0x%08h data=0x%016h strb=0x%02h id=%0d resp=%0d",
                 addr, data, strb, b_id, b_resp);
        @(posedge clk); #1;
    endtask

    // -----------------------------------------------------------------------
    // Task: AXI4 single-beat read
    //   addr  : byte address
    //   id    : AXI transaction ID
    //   rdata : returned 64-bit read data
    // -----------------------------------------------------------------------
    task automatic axi_read(
        input  logic [AXI_ADDR_WIDTH-1:0] addr,
        input  logic [AXI_ID_WIDTH-1:0]   id,
        output logic [AXI_DATA_WIDTH-1:0] rdata
    );
        @(posedge clk); #1;
        ar_valid = 1'b1;
        ar_addr  = addr;
        ar_id    = id;
        ar_len   = 8'h00;
        ar_size  = 3'b011;
        ar_burst = 2'b01;

        @(posedge clk iff ar_ready); #1;
        ar_valid = 1'b0;

        // Wait for R channel
        r_ready = 1'b1;
        @(posedge clk iff r_valid);
        rdata = r_data;
        $display("[TB] READ  done: addr=0x%08h rdata=0x%016h id=%0d resp=%0d last=%0b",
                 addr, r_data, r_id, r_resp, r_last);
        @(posedge clk); #1;
    endtask

    // -----------------------------------------------------------------------
    // Test stimulus
    // -----------------------------------------------------------------------
    int test_pass = 0;
    int test_fail = 0;

    task automatic check(
        input string       name,
        input logic [63:0] got,
        input logic [63:0] exp
    );
        if (got === exp) begin
            $display("[PASS] %s: got=0x%016h", name, got);
            test_pass++;
        end else begin
            $display("[FAIL] %s: got=0x%016h  expected=0x%016h", name, got, exp);
            test_fail++;
        end
    endtask

    logic [AXI_DATA_WIDTH-1:0] rd_data;

    initial begin
        // Wait for reset de-assertion + a few cycles
        @(posedge rst_n);
        repeat (3) @(posedge clk);

        $display("=== axi2per Testbench Start ===");

        // ------------------------------------------------------------------
        // TC1: Write lower word (addr[2]=0)
        //      AXI addr = 0x00, data[31:0] = 0xDEADBEEF
        //      Peripheral word at addr 0x00 should be 0xDEADBEEF
        // ------------------------------------------------------------------
        $display("\n-- TC1: Write lower word (addr=0x00) --");
        axi_write(32'h0000_0000, 64'hCAFE_BABE_DEAD_BEEF, 8'h0F, 3'd0);

        // ------------------------------------------------------------------
        // TC2: Write upper word (addr[2]=1)
        //      AXI addr = 0x08 (word-aligned, addr[2]=1 for 64-bit view)
        //      Actually addr[2]=1 means bit 2 of byte address = 1, i.e. addr % 8 == 4
        //      So we use addr = 0x04 → addr[2]=1
        //      data[63:32] = 0xA5A5_A5A5
        // ------------------------------------------------------------------
        $display("\n-- TC2: Write upper word (addr=0x04, addr[2]=1) --");
        axi_write(32'h0000_0004, 64'hA5A5_A5A5_1234_5678, 8'hF0, 3'd1);

        // ------------------------------------------------------------------
        // TC3: Read lower word (addr=0x00) → expect 0xDEAD_BEEF in [31:0]
        // ------------------------------------------------------------------
        $display("\n-- TC3: Read lower word (addr=0x00) --");
        axi_read(32'h0000_0000, 3'd0, rd_data);
        check("TC3 rdata[31:0]", {32'h0, rd_data[31:0]}, 64'h0000_0000_DEAD_BEEF);

        // ------------------------------------------------------------------
        // TC4: Read upper word (addr=0x04) → expect 0xA5A5_A5A5 in [63:32]
        // ------------------------------------------------------------------
        $display("\n-- TC4: Read upper word (addr=0x04) --");
        axi_read(32'h0000_0004, 3'd1, rd_data);
        check("TC4 rdata[63:32]", {rd_data[63:32], 32'h0}, 64'hA5A5_A5A5_0000_0000);

        // ------------------------------------------------------------------
        // TC5: Write then read-back, multiple addresses
        // ------------------------------------------------------------------
        $display("\n-- TC5: Write-then-read sequence --");
        axi_write(32'h0000_0010, 64'h0000_0000_1111_2222, 8'h0F, 3'd2);
        axi_write(32'h0000_0018, 64'h0000_0000_3333_4444, 8'h0F, 3'd3);
        axi_write(32'h0000_0020, 64'h0000_0000_5555_6666, 8'h0F, 3'd4);

        axi_read(32'h0000_0010, 3'd2, rd_data);
        check("TC5a addr=0x10", {32'h0, rd_data[31:0]}, 64'h0000_0000_1111_2222);

        axi_read(32'h0000_0018, 3'd3, rd_data);
        check("TC5b addr=0x18", {32'h0, rd_data[31:0]}, 64'h0000_0000_3333_4444);

        axi_read(32'h0000_0020, 3'd4, rd_data);
        check("TC5c addr=0x20", {32'h0, rd_data[31:0]}, 64'h0000_0000_5555_6666);

        // ------------------------------------------------------------------
        // TC6: Byte-enable partial write, then read
        //      Write only bytes [1:0] of addr=0x30
        // ------------------------------------------------------------------
        $display("\n-- TC6: Partial byte-enable write (be=0x03) --");
        axi_write(32'h0000_0030, 64'h0000_0000_FFFF_ABCD, 8'h03, 3'd5);
        axi_read (32'h0000_0030, 3'd5, rd_data);
        // be=0x03 → bytes [7:0] and [15:8] written → lower 16 bits = 0xABCD
        check("TC6 partial be=0x03", {48'h0, rd_data[15:0]}, 64'h0000_0000_0000_ABCD);

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("\n=== Test Summary: PASS=%0d  FAIL=%0d ===", test_pass, test_fail);

        if (test_fail == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        repeat (5) @(posedge clk);
        $finish;
    end

    // -----------------------------------------------------------------------
    // Timeout watchdog
    // -----------------------------------------------------------------------
    initial begin
        #100000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

    // -----------------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("sim/tb_axi2per.vcd");
        $dumpvars(0, tb_axi2per);
    end

endmodule
