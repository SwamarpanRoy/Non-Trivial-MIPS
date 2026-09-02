
module tb;
  reg aclk = 0;
  reg aresetn = 0;
  always #5 aclk = ~aclk;
  wire s_axi_awready, s_axi_wready, s_axi_bvalid, s_axi_arready, s_axi_rvalid;
  wire [1:0] s_axi_bresp, s_axi_rresp;
  wire [31:0] s_axi_rdata, m_apb_paddr, m_apb_pwdata;
  wire [2:0] m_apb_pprot;
  wire [3:0] m_apb_pstrb;
  wire m_apb_psel, m_apb_penable, m_apb_pwrite;
  axi_to_apb_bridge u_bridge (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_awaddr(32'h0), .s_axi_awprot(3'b0), .s_axi_awvalid(1'b0), .s_axi_awready(s_axi_awready),
    .s_axi_wdata(32'h0), .s_axi_wstrb(4'hF), .s_axi_wvalid(1'b0), .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(1'b0),
    .s_axi_araddr(32'h0), .s_axi_arprot(3'b0), .s_axi_arvalid(1'b0), .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(1'b0),
    .m_apb_paddr(m_apb_paddr), .m_apb_pprot(m_apb_pprot), .m_apb_psel(m_apb_psel), .m_apb_penable(m_apb_penable),
    .m_apb_pwrite(m_apb_pwrite), .m_apb_pwdata(m_apb_pwdata), .m_apb_pstrb(m_apb_pstrb),
    .m_apb_pready(1'b1), .m_apb_prdata(32'h0), .m_apb_pslverr(1'b0)
  );
  initial begin
    $display("Starting bridge test");
    #20 aresetn = 1;
    #20 $display("Finished bridge test");
    $finish;
  end
endmodule
