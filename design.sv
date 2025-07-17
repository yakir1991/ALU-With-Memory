`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Memory + ALU module
// This module acts as a simple 4x8 memory map with an embedded ALU.  The ALU
// is controlled through dedicated registers within the memory map.  When the
// EXECUTE bit (mem[3][0]) is asserted, the ALU performs the selected operation
// and then this bit is automatically cleared.
// -----------------------------------------------------------------------------
module memory #(parameter ADDR_WIDTH = 2, DATA_WIDTH = 8)
  (mem_if.DUT vif);

  // Memory array definition: DATA_WIDTH-bit data width, ADDR_WIDTH locations
  reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
  // Registered read data is held directly in vif.rd_data
  reg [15:0] res_out_comb; // Combinational result of ALU operations

  // Initialize memory locations to 'hFF on reset
  integer i;
  always @(posedge vif.rst) begin
    for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
      mem[i] = {DATA_WIDTH{1'b1}};  // Reset all memory locations to FF
      $display("[DUT] Memory[%0d] initialized to: %h", i, mem[i]);
    end
  end

  // Memory read/write operations and rd_data update
  // This block is the sole driver of vif.rd_data
  always @(posedge vif.clk) begin
    if (vif.rst) begin
      vif.rd_data <= {DATA_WIDTH{1'b0}};
    end else begin
      if (vif.enable) begin
        if (vif.rd_wr) begin // Read operation
          vif.rd_data <= mem[vif.addr];
          $display("[DUT] Read from Address %0d: Data = %h", vif.addr, mem[vif.addr]);
        end else begin // Write operation
          mem[vif.addr] <= vif.wr_data; // Write data to memory
          $display("[DUT] Write to Address %0d: Data = %h", vif.addr, vif.wr_data);
        end
      end
      // Self-clear the EXECUTE_REG after an ALU operation unless it is being
      // explicitly written this cycle.  This prevents repeated executions on
      // future accesses.
      if (mem[3][0] && !(vif.enable && !vif.rd_wr && vif.addr == 2'b11)) begin
        mem[3][0] <= 1'b0;
      end
      // When not performing a read, rd_data holds its previous value
    end
  end

  // Combinational ALU operations with registered output
  reg [15:0] res_out_reg;
  
  always @* begin
    res_out_comb = 16'b0; // Default value
    if (mem[3][0]) begin  // EXECUTE_REG is at address 3, bit 0
      case (mem[2][2:0])  // OPERATION_REG is at address 2
        3'b000: res_out_comb = 16'b0;               // oper=0 => res_out = 0
        3'b001: res_out_comb = mem[0] + mem[1];     // oper=1 => res_out = A + B
        3'b010: res_out_comb = mem[0] - mem[1];     // oper=2 => res_out = A - B
        3'b011: res_out_comb = mem[0] * mem[1];     // oper=3 => res_out = A * B
        3'b100: begin
          if (mem[1] != {DATA_WIDTH{1'b0}}) begin
            res_out_comb = mem[0] / mem[1];         // oper=4 => A / B
          end else begin
            res_out_comb = 16'hDEAD;                // Division by zero case
          end
        end
        default: res_out_comb = res_out_reg;       // Keep previous result for invalid oper code
      endcase
    end
    else begin
      res_out_comb = res_out_reg;  // Keep previous result when not executing
    end
  end

  // Register ALU output
  always @(posedge vif.clk) begin
    if (vif.rst) begin
      res_out_reg <= 16'b0;
    end
    else begin
      res_out_reg <= res_out_comb;
    end
  end

  // Assign registered output
  assign vif.res_out = res_out_reg;

endmodule
