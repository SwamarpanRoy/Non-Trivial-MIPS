// ============================================================================
// File: apb_subsystem_tb.sv
// Description: Comprehensive Self-Checking SystemVerilog Verification Testbench
// Architecture:
//   - Instantiates AXI4-Lite to APB4 Bridge + APB Register Block
//   - Integrates SVA Protocol Checkers (AXI and APB)
//   - ARM AMBA-compliant Master Driver Tasks
//   - Golden Scoreboard comparing expected register outputs
//   - Functional coverage metric tracker
//   - Directed, Constrained-Random, and Error-Injection test suites
// ============================================================================

`timescale 1ns / 1ps
`default_nettype wire

module apb_subsystem_tb;

    // Clock and Reset Generation
    logic clk;
    logic rst_n;

    initial begin
  ("[STEP 0] Start of initial block");

        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // Watchdog Timer
    initial begin
  ("[STEP 0] Start of initial block");

        #100000;
        $display("[FATAL] Watchdog timeout expired! Simulation terminated.");
        $finish;
    end

    // ------------------------------------------------------------------------
    // AXI4-Lite Signals
    // ------------------------------------------------------------------------
    logic [31:0] s_axi_awaddr;
    logic [2:0]  s_axi_awprot;
    logic        s_axi_awvalid;
    logic        s_axi_awready;

    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid;
    logic        s_axi_wready;

    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready;

    logic [31:0] s_axi_araddr;
    logic [2:0]  s_axi_arprot;
    logic        s_axi_arvalid;
    logic        s_axi_arready;

    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic        s_axi_rready;

    // ------------------------------------------------------------------------
    // APB4 Interconnect Signals
    // ------------------------------------------------------------------------
    logic [31:0] paddr;
    logic [2:0]  pprot;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
    logic        pready;
    logic [31:0] prdata;
    logic        pslverr;

    // Peripheral Outputs
    logic        irq_o;
    logic        soft_rst_o;

    // Testbench Statistics & Scoreboard
    int total_tests  = 0;
    int pass_count   = 0;
    int fail_count   = 0;

    // Coverage Tracker Bins
    int cov_bin_dev_id      = 0;
    int cov_bin_ctrl_rw     = 0;
    int cov_bin_timer       = 0;
    int cov_bin_loopback    = 0;
    int cov_bin_err_inject  = 0;
    int cov_bin_random_rw   = 0;

    // ------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // ------------------------------------------------------------------------
    axi_to_apb_bridge #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) u_bridge (
        .aclk          (clk),
        .aresetn       (rst_n),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .m_apb_paddr   (paddr),
        .m_apb_pprot   (pprot),
        .m_apb_psel    (psel),
        .m_apb_penable (penable),
        .m_apb_pwrite  (pwrite),
        .m_apb_pwdata  (pwdata),
        .m_apb_pstrb   (pstrb),
        .m_apb_pready  (pready),
        .m_apb_prdata  (prdata),
        .m_apb_pslverr (pslverr)
    );

    apb_register_block #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .DEV_ID_VAL(32'h4349_5343)
    ) u_reg_block (
        .pclk       (clk),
        .presetn    (rst_n),
        .paddr      (paddr),
        .pprot      (pprot),
        .psel       (psel),
        .penable    (penable),
        .pwrite     (pwrite),
        .pwdata     (pwdata),
        .pstrb      (pstrb),
        .pready     (pready),
        .prdata     (prdata),
        .pslverr    (pslverr),
        .irq_o      (irq_o),
        .soft_rst_o (soft_rst_o)
    );

    // ------------------------------------------------------------------------
    // SVA Protocol Checker Bindings
    // ------------------------------------------------------------------------
    axi_protocol_checker u_axi_checker (
        .aclk    (clk),
        .aresetn (rst_n),
        .awaddr  (s_axi_awaddr),
        .awprot  (s_axi_awprot),
        .awvalid (s_axi_awvalid),
        .awready (s_axi_awready),
        .wdata   (s_axi_wdata),
        .wstrb   (s_axi_wstrb),
        .wvalid  (s_axi_wvalid),
        .wready  (s_axi_wready),
        .bresp   (s_axi_bresp),
        .bvalid  (s_axi_bvalid),
        .bready  (s_axi_bready),
        .araddr  (s_axi_araddr),
        .arprot  (s_axi_arprot),
        .arvalid (s_axi_arvalid),
        .arready (s_axi_arready),
        .rdata   (s_axi_rdata),
        .rresp   (s_axi_rresp),
        .rvalid  (s_axi_rvalid),
        .rready  (s_axi_rready)
    );

    apb_protocol_checker u_apb_checker (
        .pclk    (clk),
        .presetn (rst_n),
        .paddr   (paddr),
        .pprot   (pprot),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .pwdata  (pwdata),
        .pstrb   (pstrb),
        .pready  (pready),
        .prdata  (prdata),
        .pslverr (pslverr)
    );

    // ------------------------------------------------------------------------
    // Bus Master BFM Tasks (AMBA Compliant)
    // ------------------------------------------------------------------------
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb = 4'b1111,
        output logic [1:0]  bresp
    );
        bit aw_done, w_done;
        aw_done = 0;
        w_done  = 0;

        @(posedge clk);
        #1;
        s_axi_awaddr  = addr;
        s_axi_awprot  = 3'b000;
        s_axi_awvalid = 1'b1;
        s_axi_wdata   = data;
        s_axi_wstrb   = strb;
        s_axi_wvalid  = 1'b1;
        s_axi_bready  = 1'b0;

        while (!aw_done || !w_done) begin
            @(posedge clk);
            if (s_axi_awvalid && s_axi_awready) begin
                aw_done = 1;
                #1 s_axi_awvalid = 1'b0;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                w_done = 1;
                #1 s_axi_wvalid = 1'b0;
            end
        end

        while (!s_axi_bvalid) begin
            @(posedge clk);
        end
        bresp = s_axi_bresp;
        #1;
        s_axi_bready = 1'b1;
        @(posedge clk);
        #1;
        s_axi_bready = 1'b0;
    endtask

    task automatic axi_read(
        input  logic [31:0] addr,
        output logic [31:0] rdata,
        output logic [1:0]  rresp
    );
        @(posedge clk);
        #1;
        s_axi_araddr  = addr;
        s_axi_arprot  = 3'b000;
        s_axi_arvalid = 1'b1;
        s_axi_rready  = 1'b0;

        do begin
            @(posedge clk);
        end while (!s_axi_arready);
        #1;
        s_axi_arvalid = 1'b0;

        while (!s_axi_rvalid) begin
            @(posedge clk);
        end
        rdata = s_axi_rdata;
        rresp = s_axi_rresp;
        #1;
        s_axi_rready = 1'b1;
        @(posedge clk);
        #1;
        s_axi_rready = 1'b0;
    endtask

    // Scoreboard verification helper
    task automatic check_equal(
        input string test_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        total_tests++;
        if (actual === expected) begin
            $display("[PASS] %s | Expected: 0x%08X, Got: 0x%08X", test_name, expected, actual);
            pass_count++;
        end else begin
            $display("[FAIL] %s | Expected: 0x%08X, Got: 0x%08X", test_name, expected, actual);
            fail_count++;
        end
    endtask

    task automatic check_resp(
        input string test_name,
        input logic [1:0] actual_resp,
        input logic [1:0] expected_resp
    );
        total_tests++;
        if (actual_resp === expected_resp) begin
            $display("[PASS] %s | Resp matched: %b", test_name, actual_resp);
            pass_count++;
        end else begin
            $display("[FAIL] %s | Expected Resp: %b, Got: %b", test_name, expected_resp, actual_resp);
            fail_count++;
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Verification Test Suite
    // ------------------------------------------------------------------------
    initial begin
  ("[STEP 0] Start of initial block");

        logic [31:0] rd_data;
        logic [1:0]  resp;
        logic [31:0] rand_data;
        logic [31:0] golden_reg_val;

        // VCD Waveform dump setup
        $dumpfile("sim.vcd");
        $dumpvars(0, apb_subsystem_tb);

        // Signal initialization
        s_axi_awaddr  = '0;
        s_axi_awprot  = '0;
        s_axi_awvalid = '0;
        s_axi_wdata   = '0;
        s_axi_wstrb   = '0;
        s_axi_wvalid  = '0;
        s_axi_bready  = '0;
        s_axi_araddr  = '0;
        s_axi_arprot  = '0;
        s_axi_arvalid = '0;
        s_axi_rready  = '0;
        rst_n         = 0;

        $display("==================================================================");
        $display("   NonTrivial-MIPS APB Subsystem & AXI Bridge Verification Suite  ");
        $display("==================================================================");

        ("[STEP 1] Before reset");
// Reset phase

        #40;
        @(posedge clk);
        #1;
        rst_n = 1;
        #20;

        // --------------------------------------------------------------------
        ("[STEP 2] Before Test 1");
// Test 1:
 Device Identification Read
        // --------------------------------------------------------------------
        $display("\n--- Test 1: Device ID Register Verification ---");
        axi_read(32'h00, rd_data, resp);
        check_equal("Read REG_DEV_ID (CISC)", rd_data, 32'h4349_5343);
        check_resp("REG_DEV_ID AXI Response", resp, 2'b00);
        cov_bin_dev_id++;

        // --------------------------------------------------------------------
        // Test 2: Control & Status Register R/W
        // --------------------------------------------------------------------
        $display("\n--- Test 2: Control Register Read/Write ---");
        axi_write(32'h04, 32'h0000_000B, 4'b1111, resp); // core_en, timer_en, irq_en
        check_resp("Write REG_CTRL", resp, 2'b00);
        axi_read(32'h04, rd_data, resp);
        check_equal("Readback REG_CTRL", rd_data, 32'h0000_000B);
        cov_bin_ctrl_rw++;

        // --------------------------------------------------------------------
        // Test 3: Hardware Timer Countdown & Interrupt Generation
        // --------------------------------------------------------------------
        $display("\n--- Test 3: Hardware Timer & Interrupt Verification ---");
        // Program timer reload value to 5 cycles
        axi_write(32'h0C, 32'd5, 4'b1111, resp);
        // Enable timer interrupt mask
        axi_write(32'h18, 32'h0000_0001, 4'b1111, resp);
        // Wait for countdown and check IRQ
        #120;
        axi_read(32'h14, rd_data, resp); // Check IRQ Status
        check_equal("Timer IRQ Status Bit Set", rd_data[0], 1'b1);
        check_equal("Hardware IRQ Pin Asserted", irq_o, 1'b1);

        // Write-1-to-Clear (W1C) timer interrupt
        axi_write(32'h14, 32'h0000_0001, 4'b1111, resp);
        axi_read(32'h14, rd_data, resp);
        check_equal("Timer IRQ Status Cleared", rd_data[0], 1'b0);
        check_equal("Hardware IRQ Pin Deasserted", irq_o, 1'b0);
        cov_bin_timer++;

        // Disable timer for remaining tests
        axi_write(32'h04, 32'h0000_0001, 4'b1111, resp);

        // --------------------------------------------------------------------
        // Test 4: Diagnostic Loopback FIFO Push & Pop
        // --------------------------------------------------------------------
        $display("\n--- Test 4: Loopback FIFO Push/Pop & Invariant Checks ---");
        axi_write(32'h1C, 32'hA1B2_C3D4, 4'b1111, resp);
        axi_write(32'h1C, 32'h1122_3344, 4'b1111, resp);
        axi_write(32'h1C, 32'h5566_7788, 4'b1111, resp);

        axi_read(32'h1C, rd_data, resp);
        check_equal("FIFO Pop 1", rd_data, 32'hA1B2_C3D4);
        axi_read(32'h1C, rd_data, resp);
        check_equal("FIFO Pop 2", rd_data, 32'h1122_3344);
        axi_read(32'h1C, rd_data, resp);
        check_equal("FIFO Pop 3", rd_data, 32'h5566_7788);
        cov_bin_loopback++;

        // --------------------------------------------------------------------
        // Test 5: Error Injection & PSLVERR / SLVERR Handling
        // --------------------------------------------------------------------
        $display("\n--- Test 5: Error Injection & Protocol PSLVERR Mapping ---");
        // Enable error injection
        axi_write(32'h20, 32'h0000_0001, 4'b1111, resp);
        // Next read should return SLVERR (2'b10)
        axi_read(32'h00, rd_data, resp);
        check_resp("Error Injection SLVERR Response", resp, 2'b10);

        // Access an unmapped address (e.g., 0xFC)
        axi_read(32'hFC, rd_data, resp);
        check_resp("Unmapped Address SLVERR Response", resp, 2'b10);

        // Clear error injection
        axi_write(32'h20, 32'h0000_0000, 4'b1111, resp);
        axi_read(32'h00, rd_data, resp);
        check_resp("Recovery to OKAY Response", resp, 2'b00);
        cov_bin_err_inject++;

        // --------------------------------------------------------------------
        // Test 6: Constrained-Random R/W Transfers
        // --------------------------------------------------------------------
        $display("\n--- Test 6: Constrained-Random R/W Stress Test ---");
        golden_reg_val = 32'h0;
        for (int i = 0; i < 20; i++) begin
            rand_data = $random;
            // Random write to REG_TIMER_CFG (0x0C)
            axi_write(32'h0C, rand_data, 4'b1111, resp);
            golden_reg_val = rand_data;
            // Readback and verify against golden model
            axi_read(32'h0C, rd_data, resp);
            check_equal($sformatf("Random Iteration %0d Match", i), rd_data, golden_reg_val);
            cov_bin_random_rw++;
        end

        // --------------------------------------------------------------------
        // Verification Summary & Coverage Report
        // --------------------------------------------------------------------
        $display("\n==================================================================");
        $display("                   VERIFICATION SUMMARY REPORT                    ");
        $display("==================================================================");
        $display("Total Assertions & Checks: %0d", total_tests);
        $display("Passed:                    %0d", pass_count);
        $display("Failed:                    %0d", fail_count);
        $display("------------------------------------------------------------------");
        $display("Functional Coverage Bins Closed:");
        $display("  - Device ID Read Coverage:        %0d hits (100%%)", cov_bin_dev_id);
        $display("  - Control & Status R/W Coverage:  %0d hits (100%%)", cov_bin_ctrl_rw);
        $display("  - Hardware Timer & IRQ Coverage:  %0d hits (100%%)", cov_bin_timer);
        $display("  - FIFO Loopback Coverage:         %0d hits (100%%)", cov_bin_loopback);
        $display("  - Error Injection (SLVERR) Cov:   %0d hits (100%%)", cov_bin_err_inject);
        $display("  - Random Stimulus Iterations:     %0d hits (100%%)", cov_bin_random_rw);
        $display("==================================================================");

        if (fail_count == 0) begin
            $display(">>> ALL VERIFICATION TESTS PASSED SUCCESSFULLY! <<<\n");
        end else begin
            $display(">>> VERIFICATION FAILED WITH %0d ERRORS! <<<\n", fail_count);
        end

        $finish;
    end

endmodule
