`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Input monitor
// Captures transactions going into the DUT for checking and coverage
// -----------------------------------------------------------------------------
class monitor_in;
  
  // Virtual interface handle
  virtual mem_if vif;
  
  // Mailbox to send the monitored transactions to the scoreboard
  mailbox mon_in2scb;
  
  // Constructor
  // This function initializes the monitor_in class with a virtual interface and a mailbox.
  function new(virtual mem_if vif, mailbox mon_in2scb);
    this.vif = vif; // Assign the virtual interface
    this.mon_in2scb = mon_in2scb; // Assign the mailbox
  endfunction
  
  // Main task to monitor inputs
  task main();
    transaction trans;
    
    forever begin
      trans = new(); // Create a new transaction object
      
      // Sample the input signals at the next positive clock edge
      @(posedge vif.clk);
      
      if (vif.rst) begin
        // Capture reset state
        trans.rst = vif.rst;
        trans.enable = 0;
        trans.rd_wr = 0;
        trans.addr = '0;
        trans.wr_data = '0;
        
        $display("[Monitor_In] Reset detected"); // Display a message indicating reset detection
        trans.display("[Monitor_In]"); // Display the transaction details
        mon_in2scb.put(trans); // Send the transaction to the scoreboard
      end 
      else if (vif.enable) begin
        // Capture all input signals
        trans.rst = vif.rst;
        trans.enable = vif.enable;
        trans.rd_wr = vif.rd_wr;
        trans.addr = vif.addr;
        trans.wr_data = vif.wr_data;
        
        // Special handling for different register types
        case (trans.addr)
          2'b00, 2'b01: begin // A_REG or B_REG
            $display("[Monitor_In] Data Register Access: Addr=%0d, Data=%0h", 
                     trans.addr, trans.wr_data);
          end
          
          2'b10: begin // OPERATION_REG
            if (!trans.rd_wr) begin // Write operation
              $display("[Monitor_In] Operation Register Write: Operation=%0d", 
                       trans.wr_data[2:0]);
              if (|trans.wr_data[7:3]) begin
                $warning("[Monitor_In] Reserved bits in OPERATION_REG are not zero!");
              end
            end
          end
          
          2'b11: begin // EXECUTE_REG
            if (!trans.rd_wr) begin // Write operation
              $display("[Monitor_In] Execute Register Write: Execute=%0b", 
                       trans.wr_data[0]);
              if (|trans.wr_data[7:1]) begin
                $warning("[Monitor_In] Reserved bits in EXECUTE_REG are not zero!");
              end
            end
          end
        endcase
        
        // Display and send the transaction
        trans.display("[Monitor_In]");
        mon_in2scb.put(trans);
      end
    end
  endtask

endclass
