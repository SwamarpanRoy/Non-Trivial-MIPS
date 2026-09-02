
module tb;
  reg pclk = 0;
  reg presetn = 0;
  always #5 pclk = ~pclk;
  wire pready, pslverr, irq_o, soft_rst_o;
  wire [31:0] prdata;
  apb_register_block u_reg (
    .pclk(pclk), .presetn(presetn), .paddr(32'h0), .pprot(3'b0),
    .psel(1'b0), .penable(1'b0), .pwrite(1'b0), .pwdata(32'h0), .pstrb(4'hF),
    .pready(pready), .prdata(prdata), .pslverr(pslverr), .irq_o(irq_o), .soft_rst_o(soft_rst_o)
  );
  initial begin
    $display("Starting apb_reg test");
    #20 presetn = 1;
    #20 $display("Finished apb_reg test");
    $finish;
  end
endmodule
