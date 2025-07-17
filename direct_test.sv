/*******************************************************************************
* Direct Test for ALU with Memory
* -------------------
* This test program performs directed testing of the ALU with Memory module.
* It covers:
* 1. Basic memory read/write operations
* 2. Memory reset functionality
* 3. ALU operations (ADD, SUB, MUL, DIV)
* 4. Error conditions (division by zero)
* 5. Reserved bits violations
* 6. Reset during operations
*
* Memory Map:
* - Address 0 (A_REG): Data Register A
* - Address 1 (B_REG): Data Register B
* - Address 2 (OPERATION_REG): ALU Operation Selection [2:0], bits [7:3] reserved
* - Address 3 (EXECUTE_REG): Execute bit [0], bits [7:1] reserved
*******************************************************************************/

program direct_test(mem_if vif);

  initial begin
    // ----------------------------------------
    // 1. Write and Read to a specific memory location
    // ----------------------------------------
    $display("\n=== Test 1: Basic Memory Access ===");
    vif.addr <= 2'b01;  // Fixed: Using 2-bit address
    vif.wr_data <= 8'hAA;
    vif.rd_wr <= 0;
    vif.enable <= 1;
    @(posedge vif.clk);
    vif.enable <= 0;

    @(posedge vif.clk);

    vif.rd_wr <= 1;
    vif.enable <= 1;
    @(posedge vif.clk);
    vif.enable <= 0;

    @(posedge vif.clk);
    
    if (vif.rd_data !== 8'hAA) begin
      $display("ERROR: Read data does not match written data at address 2'b01");
    end else begin
      $display("PASS: Read data matches written data at address 2'b01");
    end

    // ----------------------------------------
    // 2. Memory Scan - Test all memory locations
    // ----------------------------------------
    $display("\n=== Test 2: Full Memory Scan ===");
    for (int i = 0; i < 4; i++) begin  // Fixed: Testing only 4 locations
      vif.addr <= i[1:0];  // Fixed: Using 2-bit address
      vif.wr_data <= 8'hA0 + i;
      vif.rd_wr <= 0;
      vif.enable <= 1;
      @(posedge vif.clk);
      vif.enable <= 0;

      @(posedge vif.clk);

      vif.rd_wr <= 1;
      vif.enable <= 1;
      @(posedge vif.clk);
      vif.enable <= 0;

      @(posedge vif.clk);

      if (vif.rd_data !== (8'hA0 + i)) begin
        $display("ERROR: Address %0d - Expected: %0h, Got: %0h", i, 8'hA0 + i, vif.rd_data);
      end else begin
        $display("PASS: Address %0d - Data matches", i);
      end
    end

    // ----------------------------------------
    // 3. ALU Operations Test
    // ----------------------------------------
    $display("\n=== Test 3: ALU Operations ===");
    
    // Write test values: A = 10, B = 2
    vif.rd_wr <= 0;
    vif.enable <= 1;

    // Write A_REG
    vif.addr <= 2'b00;
    vif.wr_data <= 8'd10;
    @(posedge vif.clk);

    // Write B_REG
    vif.addr <= 2'b01;
    vif.wr_data <= 8'd2;
    @(posedge vif.clk);

    // Test each operation
    for (int op = 0; op <= 4; op++) begin
      // Set operation
      vif.addr <= 2'b10;  // OPERATION_REG
      vif.wr_data <= op;
      @(posedge vif.clk);

      // Set execute
      vif.addr <= 2'b11;  // EXECUTE_REG
      vif.wr_data <= 8'h01;
      @(posedge vif.clk);

      vif.enable <= 0;
      repeat(2) @(posedge vif.clk);

      case(op)
        0: if (vif.res_out === 16'h0)     $display("PASS: NOP operation");
           else                            $display("ERROR: NOP - Expected: 0, Got: %0h", vif.res_out);
        1: if (vif.res_out === 16'd12)    $display("PASS: ADD operation (10 + 2 = 12)");
           else                            $display("ERROR: ADD - Expected: 12, Got: %0h", vif.res_out);
        2: if (vif.res_out === 16'd8)     $display("PASS: SUB operation (10 - 2 = 8)");
           else                            $display("ERROR: SUB - Expected: 8, Got: %0h", vif.res_out);
        3: if (vif.res_out === 16'd20)    $display("PASS: MUL operation (10 * 2 = 20)");
           else                            $display("ERROR: MUL - Expected: 20, Got: %0h", vif.res_out);
        4: if (vif.res_out === 16'd5)     $display("PASS: DIV operation (10 / 2 = 5)");
           else                            $display("ERROR: DIV - Expected: 5, Got: %0h", vif.res_out);
      endcase

      vif.enable <= 1;
    end

    // ----------------------------------------
    // 4. Division by Zero Test
    // ----------------------------------------
    $display("\n=== Test 4: Division by Zero ===");
    
    // Set B = 0
    vif.addr <= 2'b01;
    vif.wr_data <= 8'd0;
    @(posedge vif.clk);

    // Set division operation
    vif.addr <= 2'b10;
    vif.wr_data <= 8'h04;  // DIV operation
    @(posedge vif.clk);

    // Execute
    vif.addr <= 2'b11;
    vif.wr_data <= 8'h01;
    @(posedge vif.clk);

    vif.enable <= 0;
    repeat(2) @(posedge vif.clk);

    if (vif.res_out === 16'hDEAD) begin
      $display("PASS: Division by zero correctly returned 0xDEAD");
    end else begin
      $display("ERROR: Division by zero - Expected: 0xDEAD, Got: %0h", vif.res_out);
    end

    // ----------------------------------------
    // 5. Reserved Bits Test
    // ----------------------------------------
    $display("\n=== Test 5: Reserved Bits Test ===");
    vif.enable <= 1;

    // Test OPERATION_REG reserved bits
    vif.addr <= 2'b10;
    vif.wr_data <= 8'hF0;  // Set reserved bits [7:3]
    @(posedge vif.clk);
    
    // Test EXECUTE_REG reserved bits
    vif.addr <= 2'b11;
    vif.wr_data <= 8'hFE;  // Set reserved bits [7:1]
    @(posedge vif.clk);

    vif.enable <= 0;
    @(posedge vif.clk);

    // ----------------------------------------
    // 6. Reset Test
    // ----------------------------------------
    $display("\n=== Test 6: Reset Test ===");
    vif.rst <= 1;
    @(posedge vif.clk);
    vif.rst <= 0;

    // Verify all addresses return to default value
    vif.rd_wr <= 1;
    for (int i = 0; i < 4; i++) begin
      vif.addr <= i[1:0];  // Fixed: Using 2-bit address
      vif.enable <= 1;
      @(posedge vif.clk);
      vif.enable <= 0;
      @(posedge vif.clk);

      if (vif.rd_data !== 8'hFF) begin
        $display("ERROR: Address %0d not reset to 0xFF", i);
      end else begin
        $display("PASS: Address %0d correctly reset to 0xFF", i);
      end
    end

    $display("\n=== Direct Test Complete ===\n");
    $finish;
  end

endprogram
