
module apb_subsystem_tb;
  reg clk = 0;
  reg rst_n = 0;
  always #5 clk = ~clk;

  initial begin
    $display("HELLO WORLD!");
    $finish;
  end
endmodule
