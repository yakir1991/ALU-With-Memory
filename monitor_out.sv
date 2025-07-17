`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Output monitor
// Observes DUT outputs such as read data and ALU results
// -----------------------------------------------------------------------------
class monitor_out;
  
  // Virtual interface handle
  virtual mem_if vif;
  
  // Mailbox to send the monitored transactions to the scoreboard
  mailbox mon_out2scb;
  
  // Previous values for edge detection
  bit [15:0] prev_res_out;
  bit [7:0] prev_rd_data;
  bit prev_read_pending;
  
  // Constructor
  // This function initializes the monitor_out class with a virtual interface and a mailbox.
  function new(virtual mem_if vif, mailbox mon_out2scb);
    this.vif = vif; // Assign the virtual interface
    this.mon_out2scb = mon_out2scb; // Assign the mailbox
    prev_res_out = 16'h0; // Initialize previous result output to 0
    prev_rd_data = 8'h0; // Initialize previous read data to 0
    prev_read_pending = 0; // Initialize previous read pending flag to 0
  endfunction
  
  // Main task to monitor outputs
  task main();
    transaction trans;
    
    forever begin
      trans = new(); // Create a new transaction object
      
      @(posedge vif.clk); // Wait for the next positive clock edge
      
      // Handle reset
      if (vif.rst) begin
        prev_res_out = 16'h0; // Reset previous result output
        prev_rd_data = 8'h0; // Reset previous read data
        prev_read_pending = 0; // Reset previous read pending flag
        continue; // Continue to the next iteration of the loop
      end
      
      // Monitor read data
      if (prev_read_pending) begin
        // Use clocking block to sample read data
        trans.rd_data = vif.rd_data; // Capture the read data
        trans.res_out = vif.res_out; // Capture the result output
        mon_out2scb.put(trans); // Send the transaction to the scoreboard
        prev_read_pending = 0;
      end
      
      // Set read_pending for next cycle if current cycle is a read
      if (vif.enable && vif.rd_wr) begin
        prev_read_pending = 1;
        // Wait for read data to be valid using clocking block timing
        @(posedge vif.clk);
        @(posedge vif.clk);
      end
      
      // Monitor res_out changes using clocking block
      if (vif.res_out !== prev_res_out) begin
        trans = new();
        trans.res_out = vif.res_out;
        
        // Special handling for division by zero case
        if (vif.res_out === 16'hDEAD) begin
          $display("[Monitor_Out] Division by Zero detected! res_out = 0xDEAD");
        end else begin
          $display("[Monitor_Out] ALU Result changed: %0h", vif.res_out);
        end
        
        mon_out2scb.put(trans);
        prev_res_out = vif.res_out;
      end
    end
  endtask

endclass
