`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Driver class
// Receives transactions from the generator and drives them to the DUT
// -----------------------------------------------------------------------------
class driver;
  // Count the number of transactions driven
  int num_transactions;

  // Virtual interface handle
  virtual mem_if vif;
  
  // Mailbox handle to receive transactions from generator
  mailbox gen2drv;
  
  // Constructor
  // This function initializes the driver class with a virtual interface and a mailbox.
  function new(virtual mem_if vif, mailbox gen2drv);
    this.vif = vif; // Assign the virtual interface
    this.gen2drv = gen2drv; // Assign the mailbox
    num_transactions = 0; // Initialize the transaction count to 0
  endfunction
  
  // Reset task
  // This task performs a reset sequence on the virtual interface.
  task reset();
    $display("[Driver] Reset Started"); // Display a message indicating reset start
    vif.rst <= 1; // Assert the reset signal
    vif.drv_cb.enable <= 0; // Disable the driver callback
    // Set bus direction: 0 = write, 1 = read
    vif.drv_cb.rd_wr <= 1; // Hold read mode during reset
    vif.drv_cb.addr <= '0; // Clear the address
    vif.drv_cb.wr_data <= '0; // Clear the write data
    repeat(5) @(posedge vif.clk); // Hold reset for 5 clock cycles
    vif.rst <= 0; // Deassert the reset signal
    @(posedge vif.clk); // Wait for one clock cycle
    $display("[Driver] Reset Ended"); // Display a message indicating reset end
  endtask

  // Task for write operations
  // This task performs a write operation using the provided transaction.
  task write_operation(transaction trans);
    // Setup write signals
    vif.drv_cb.addr <= trans.addr; // Set the address from the transaction
    vif.drv_cb.wr_data <= trans.wr_data; // Set the write data from the transaction
    vif.drv_cb.rd_wr <= 0; // Set read/write to write
    
    // Enable write on next clock
    @(posedge vif.clk);
    vif.drv_cb.enable <= 1;
    
    // Log the operation
    $display("[Driver] Write Operation: Addr=%0h, Data=%0h", trans.addr, trans.wr_data);
    
    // Wait for write to complete
    @(posedge vif.clk);
    vif.drv_cb.enable <= 0;
    
    // Wait for data to stabilize
    repeat(2) @(posedge vif.clk);
  endtask

  // Task for read operations
  task read_operation(transaction trans);
    // Setup read signals
    vif.drv_cb.addr <= trans.addr;
    vif.drv_cb.rd_wr <= 1;
    
    // Enable read on next clock
    @(posedge vif.clk);
    vif.drv_cb.enable <= 1;
    
    // Log the operation
    $display("[Driver] Read Operation: Addr=%0h", trans.addr);
    
    // Wait for one clock cycle
    @(posedge vif.clk);
    vif.drv_cb.enable <= 0;
    
    // Wait two more cycles for read data to be valid
    repeat(2) @(posedge vif.clk);
    
    // Capture read data using clocking block
    trans.rd_data = vif.drv_cb.rd_data;
    $display("[Driver] Read Data Captured: %0h", trans.rd_data);
  endtask

  // Drive task - drives the transaction items to interface signals
  task drive();
    transaction trans;
    
    // Get transaction from mailbox
    gen2drv.get(trans);
    
    $display("--------- [Driver-TRANSFER: %0d] ---------", num_transactions);
    
    // Handle reset transaction
    if (trans.rst) begin
      reset();
      num_transactions++;
      return;
    end
    
    // Wait for any previous transaction to complete
    @(posedge vif.clk);
    
    // Drive transaction based on type
    if (trans.rd_wr == 0) begin
      write_operation(trans);
    end else begin
      read_operation(trans);
    end
    
    // Log special register operations
    if (trans.addr == 2 && !trans.rd_wr) begin
      $display("[Driver] Operation Register Write: %0h", trans.wr_data[2:0]);
    end
    if (trans.addr == 3 && !trans.rd_wr) begin
      $display("[Driver] Execute Register Write: %0b", trans.wr_data[0]);
    end
    
    // Sample res_out for ALU operations using clocking block
    trans.res_out = vif.drv_cb.res_out;
    if (trans.addr == 3 && trans.wr_data[0]) begin
      $display("[Driver] ALU Result: %0h", trans.res_out);
    end
    
    num_transactions++;
  endtask

  // Main task
  task main();
    $display("[Driver] Starting...");
    
    // Initial reset
    reset();
    
    // Process transactions forever
    forever begin
      drive();
    end
  endtask

endclass
