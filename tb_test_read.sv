
module apb_subsystem_tb;
    logic clk = 0;
    logic rst_n = 0;
    always #5 clk = ~clk;

    logic [31:0] s_axi_awaddr = 0;
    logic [2:0]  s_axi_awprot = 0;
    logic        s_axi_awvalid = 0;
    logic        s_axi_awready;
    logic [31:0] s_axi_wdata = 0;
    logic [3:0]  s_axi_wstrb = 0;
    logic        s_axi_wvalid = 0;
    logic        s_axi_wready;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready = 0;
    logic [31:0] s_axi_araddr = 0;
    logic [2:0]  s_axi_arprot = 0;
    logic        s_axi_arvalid = 0;
    logic        s_axi_arready;
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic        s_axi_rready = 0;

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
    logic        irq_o;
    logic        soft_rst_o;

    axi_to_apb_bridge u_bridge (
        .aclk(clk), .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(s_axi_awprot), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(s_axi_arprot), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .m_apb_paddr(paddr), .m_apb_pprot(pprot), .m_apb_psel(psel), .m_apb_penable(penable),
        .m_apb_pwrite(pwrite), .m_apb_pwdata(pwdata), .m_apb_pstrb(pstrb),
        .m_apb_pready(pready), .m_apb_prdata(prdata), .m_apb_pslverr(pslverr)
    );

    apb_register_block u_reg (
        .pclk(clk), .presetn(rst_n),
        .paddr(paddr), .pprot(pprot), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .pstrb(pstrb),
        .pready(pready), .prdata(prdata), .pslverr(pslverr),
        .irq_o(irq_o), .soft_rst_o(soft_rst_o)
    );

    
    axi_protocol_checker u_axi_checker (
        .aclk(clk), .aresetn(rst_n),
        .awaddr(s_axi_awaddr), .awprot(s_axi_awprot), .awvalid(s_axi_awvalid), .awready(s_axi_awready),
        .wdata(s_axi_wdata), .wstrb(s_axi_wstrb), .wvalid(s_axi_wvalid), .wready(s_axi_wready),
        .bresp(s_axi_bresp), .bvalid(s_axi_bvalid), .bready(s_axi_bready),
        .araddr(s_axi_araddr), .arprot(s_axi_arprot), .arvalid(s_axi_arvalid), .arready(s_axi_arready),
        .rdata(s_axi_rdata), .rresp(s_axi_rresp), .rvalid(s_axi_rvalid), .rready(s_axi_rready)
    );

    apb_protocol_checker u_apb_checker (
        .pclk(clk), .presetn(rst_n),
        .paddr(paddr), .pprot(pprot), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .pstrb(pstrb),
        .pready(pready), .prdata(prdata), .pslverr(pslverr)
    );

    
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
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


    logic [31:0] rd_data;
    logic [1:0]  resp;

    initial begin
        $display("TIME 0: STARTED TB");
        #40;
        rst_n = 1;
        $display("TIME 40: RESET RELEASED");
        #20;
        $display("Starting AXI Read of DEV_ID...");
        axi_read(32'h00, rd_data, resp);
        $display("READ COMPLETED! Data = 0x%08X, Resp = %b", rd_data, resp);
        $finish;
    end

        $display("TIME 0: STARTED TB WITH BRIDGE & REG");
        #40;
        rst_n = 1;
        $display("TIME 40: RESET RELEASED");
        #100;
        $display("TIME 140: FINISHED");
        $finish;
    end
endmodule
