// -----------------------------------------------------------------------------
// Bus interface connecting the testbench and DUT
// Provides clocking blocks, modports and protocol assertions
// -----------------------------------------------------------------------------
interface mem_if(input logic clk);
  
  // Interface signals
  logic enable;
  logic rd_wr;
  logic rst;
  logic [1:0] addr;      // 2-bit address
  logic [7:0] wr_data;   // 8-bit write data
  logic [7:0] rd_data;   // 8-bit read data
  logic [15:0] res_out;  // 16-bit ALU result

  // Clocking block for driver
  clocking drv_cb @(posedge clk);
    default input #1step output #1step;
    output enable, rd_wr, addr, wr_data, rst;
    input rd_data, res_out;
  endclocking

  // Clocking block for monitor_in
  clocking mon_in_cb @(posedge clk);
    default input #1step;
    input enable, rd_wr, addr, wr_data, rst;
  endclocking

  // Clocking block for monitor_out
  clocking mon_out_cb @(posedge clk);
    default input #1step;
    input rd_data, res_out;
  endclocking

  // Modports
  modport DUT (
    input clk, rst, enable, rd_wr, addr, wr_data,
    output rd_data, res_out
  );

  modport driver (
    clocking drv_cb,
    output rst
  );

  modport monitor_in (
    clocking mon_in_cb
  );

  modport monitor_out (
    clocking mon_out_cb
  );

  // =========================================================================
  // Helper assertions for timing verification
  // =========================================================================

  // 1) Valid read timing:
  //    After (enable && rd_wr) = 1 (read), we expect rd_data to remain stable
  //    2 cycles later. (Adjust ##2 as needed)
  property valid_read_timing;
    @(posedge clk)
    (enable && rd_wr) |=> ##2 $stable(rd_data);
  endproperty

  assert property(valid_read_timing)
    else $error("Read timing violation detected");

  // 2) Valid write timing:
  //    After (enable && !rd_wr) = 1 (write), wr_data should remain stable after 1 cycle.
  property valid_write_timing;
    @(posedge clk)
    (enable && !rd_wr) |=> ##1 $stable(wr_data);
  endproperty

  assert property(valid_write_timing)
    else $error("Write timing violation detected");

  // =========================================================================
  // Additional Assertions
  // =========================================================================

  // 3) No read/write if reset is active:
  //    If rst=1, we assume no valid read/write should occur in the same cycle.
  //    (You can remove or invert this if your design allows read/write during reset).
  property no_op_during_reset;
    @(posedge clk)
    rst |-> !(enable); 
    // i.e. if rst is high, 'enable' must be low (no memory operation).
  endproperty

  assert property(no_op_during_reset)
    else $error("Operation (enable=1) during reset detected");

  // 4) Cannot perform read and write simultaneously in the same cycle:
  //    Since rd_wr is a single bit, we check if it's 'X' or contradictory state.
  //    This is more of a sanity check that rd_wr won't glitch to 0 and 1 in the same cycle.
  //    For example, if design insists rd_wr must be strictly 0 or 1, never 'X'.
  property no_unknown_rdwr;
    @(posedge clk)
    (!($isunknown(rd_wr))) == 1;  // rd_wr shouldn't be 'X' or 'Z'
  endproperty

  assert property(no_unknown_rdwr)
    else $error("rd_wr is unknown (X/Z) in the same cycle");

  // 5) If enable=1, address must remain stable for the cycle:
  //    This ensures that once we start an operation, 'addr' doesn't change mid-cycle.
  //    We can use |-> ##1 $stable(addr), so we check next clock, or in the same cycle.
  property stable_address_during_enable;
    @(posedge clk)
    enable |-> ##1 $stable(addr);
  endproperty

  assert property(stable_address_during_enable)
    else $error("Address changed while enable=1, violating stable timing");

  // 6) If we do a write (!rd_wr) with enable=1, data must not be X:
  //    Basic check to ensure we don't write unknown values.
  property no_x_wr_data_when_write;
    @(posedge clk)
    (enable && !rd_wr) |-> (!($isunknown(wr_data)));
  endproperty

  assert property(no_x_wr_data_when_write)
    else $error("Writing unknown (X) data in wr_data");

  // =========================================================================
  // Additional timing checks
  // =========================================================================
  always @(posedge clk) begin
    // Warn if control signals are unknown
    if ($isunknown({enable, rd_wr, addr}))
      $warning("Control signals have unknown values");

    // Check for valid address range [0..3]
    // (You already do this check conditionally, but let's keep it for clarity).
    if (enable && (addr > 2'b11))
      $error("Invalid address detected: %h", addr);
  end

endinterface
