`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Transaction class
// Represents a single bus operation with randomizable fields
// -----------------------------------------------------------------------------
class transaction;

  // Declare transaction fields
  rand bit [1:0] addr;        // Changed to 2 bits according to ADDR_WIDTH=2
  rand bit [7:0] wr_data;     // Write data (8 bits)
  rand bit rd_wr;             // Read/Write signal (0: Write, 1: Read)
  bit [7:0] rd_data;          // Read data (captured during read operations)
  rand bit enable;            // Enable signal
  rand bit rst;               // Reset signal
  bit [15:0] res_out;         // ALU result output

  // Constraint to make enable more often '1' (95% of the time)
  constraint c_enable {
    enable dist {1:=95, 0:=5};
  }

  // Constraint to make reset less frequent (5% of the time)
  constraint c_rst {
    rst dist {1:=5, 0:=95};
  }

  // Constraint for address to be within valid range (0-3)
  constraint c_addr {
    addr inside {[0:3]};  // Only valid addresses according to ADDR_WIDTH=2
  }

  // Constraint for write data when addr is EXECUTE_REG (addr=3)
  // Only bit 0 should be modifiable, others are reserved
  constraint c_wr_data_execute_reg {
    if (addr == 3) {
      wr_data[7:1] == 0;  // Reserved bits must be 0
      wr_data[0] dist {1:=80, 0:=20};  // EXECUTE bit more often 1
    }
  }

  // Constraint for write data when addr is OPERATION_REG (addr=2)
  // Only bits [2:0] should be modifiable, others are reserved
  constraint c_wr_data_operation_reg {
    if (addr == 2) {
      wr_data[7:3] == 0;  // Reserved bits must be 0
      wr_data[2:0] inside {[0:4]};  // Valid operation codes only
    }
  }

  // Constraints for data registers (A_REG=0, B_REG=1)
  constraint c_wr_data_data_regs {
    if (addr inside {0, 1}) {
      wr_data inside {[0:255]};  // Full range for data registers
    }
  }

  // Constraint for read/write operations
  constraint c_rd_wr {
    if (rst == 1) {
      rd_wr == 0;  // During reset, only allow writes
    } else {
      rd_wr dist {0:=70, 1:=30};  // More writes than reads
    }
  }

  // Display function for debugging
  function void display(string name);
    $display("------------- %s -------------", name);
    $display("Address: %0d", addr);
    $display("Write Data: %0h", wr_data);
    $display("Read/Write: %0b (0: Write, 1: Read)", rd_wr);
    if (rd_wr == 1) begin
      $display("Read Data: %0h", rd_data);
    end
    $display("Enable: %0b", enable);
    $display("Reset: %0b", rst);
    if (addr == 2) begin
      $display("Operation Code: %0d", wr_data[2:0]);
    end
    if (addr == 3) begin
      $display("Execute Bit: %0b", wr_data[0]);
    end
    $display("ALU Result: %0h", res_out);
    $display("------------------------------------");
  endfunction

endclass
