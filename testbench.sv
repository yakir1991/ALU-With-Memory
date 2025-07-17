// -----------------------------------------------------------------------------
// Top level testbench
// Generates the clock, instantiates the interface, DUT and test program
// -----------------------------------------------------------------------------
// Author: Yakir Aqua

module testbench_top;

  // Declare clock and reset signals
  bit clk = 0;
  bit rst;

  // Clock generation: Toggle clk every 5 time units
  always #5 clk = ~clk;

  // VCD dump for waveform viewing
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end

  // Instantiate interface to connect DUT and testbench
  mem_if vif(clk);  // Updated to use the ALU memory interface

  // Instantiate the test program, pass interface handle
  test t1(vif);

  // Instantiate DUT (Device Under Test), pass interface handle
  memory DUT (vif);  // Updated to use the ALU with memory DUT
  
  // Instantiate the direct test
  //direct_test d_test(vif);  // Run the direct test

endmodule
