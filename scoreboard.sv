class scoreboard;

  // =========================================================================
  // Class variables
  // =========================================================================
  int num_passed, num_failed, num_transactions;
  bit [7:0] mem_expected [0:3];    // Expected memory state
  bit [15:0] alu_result_expected;  // Expected ALU result
  
  // Configuration parameters
  int transaction_timeout;        // Timeout for transactions
  int max_transactions;           // Maximum number of transactions to process
  bit verbose;                    // Enable/disable verbose logging
  
  mailbox mon_in2scb, mon_out2scb;
  event test_done;  // Event to signal test completion

  // =========================================================================
  // Coverage-related variables (for manual sampling)
  // =========================================================================
  // We'll store the relevant fields from 'in_trans' here before sampling
  bit [1:0] cov_addr;
  bit       cov_rd_wr;
  bit [7:0] cov_wr_data;

  // Variable to keep track of the read/write operations
  bit cp_rd_wr;

  // =========================================================================
  // Covergroup (Manual Sampling)
  // =========================================================================
  covergroup scoreboard_cg;
    option.per_instance = 1;

    // Coverpoint for 'addr'
    cp_addr: coverpoint cov_addr {
      bins addr_0 = {0};
      bins addr_1 = {1};
      bins addr_2 = {2};
      bins addr_3 = {3};
    }

    // Coverpoint for 'rd_wr' (write=0, read=1)
    cp_rd_wr: coverpoint cov_rd_wr {
      bins write_val = {0};
      bins read_val  = {1};
    }

    // Cross coverage between addr and rd_wr
    cross cp_addr, cp_rd_wr;

    // Coverpoint for operation code in wr_data[2:0], only when writing to addr=2
    cp_operation: coverpoint cov_wr_data[2:0]
      iff (cov_addr == 2 && cov_rd_wr == 0)
    {
      bins oper_0 = {0};   // NOP
      bins oper_1 = {1};   // ADD
      bins oper_2 = {2};   // SUB
      bins oper_3 = {3};   // MUL
      bins oper_4 = {4};   // DIV
      bins others = {[5:7]};
    }

    // Optionally: coverpoint for EXECUTE bit (cov_wr_data[0] when addr=3, write=0)
    cp_execute: coverpoint cov_wr_data[0]
      iff (cov_addr == 3 && cov_rd_wr == 0)
    {
      bins exec_0 = {0};
      bins exec_1 = {1};
    }

  endgroup

  // =========================================================================
  // Constructor
  // =========================================================================
  function new(mailbox mon_in2scb, mailbox mon_out2scb);
    this.mon_in2scb = mon_in2scb;
    this.mon_out2scb = mon_out2scb;

    num_passed = 0;
    num_failed = 0;
    num_transactions = 0;
    transaction_timeout = 50;    // Shorter timeout
    max_transactions = 100;      // Max transactions
    verbose = 0;

    // Initialize memory to 0xFF
    foreach(mem_expected[i]) begin
      mem_expected[i] = 8'hFF;
      if (verbose) $display("[Scoreboard] Init mem[%0d] = 0xFF", i);
    end
    alu_result_expected = 16'b0;

    // Instantiate covergroup
    scoreboard_cg = new();
  endfunction

  // =========================================================================
  // Print memory state only for errors or when forced
  // =========================================================================
  function void print_mem_expected(bit print_flag);
    if (print_flag) begin
      $display("[Scoreboard] Memory State @ %0d:", num_transactions);
      foreach(mem_expected[i]) begin
        $display("  [%0d]: 0x%0h", i, mem_expected[i]);
      end
    end
  endfunction

  // =========================================================================
  // Coverage Sampling Method
  // =========================================================================
  function void sample_in_transaction(transaction t);
    // Copy fields from 't' into our local coverage variables
    cov_addr   = t.addr;
    cov_rd_wr  = t.rd_wr;
    cov_wr_data= t.wr_data;

    // Now manually sample the coverage
    scoreboard_cg.sample();
  endfunction

  // =========================================================================
  // Handle Write
  // =========================================================================
  task handle_write(transaction trans);
    bit [7:0] old_value = mem_expected[trans.addr];
    mem_expected[trans.addr] = trans.wr_data;
    
    if (old_value !== trans.wr_data && verbose) begin
      $display("[Scoreboard] Write A%0d: 0x%0h->0x%0h", 
               trans.addr, old_value, trans.wr_data);
    end
  endtask

  // =========================================================================
  // Handle Read
  // =========================================================================
  task handle_read(transaction in_trans, transaction out_trans);
    bit [7:0] expected_data = mem_expected[in_trans.addr];
    
    if (out_trans.rd_data !== expected_data) begin
      $error("[Scoreboard] READ FAIL A%0d: E=0x%0h,A=0x%0h",
             in_trans.addr, expected_data, out_trans.rd_data);
      print_mem_expected(1); // Print memory on error
      num_failed++;
    end else begin
      num_passed++;
    end
  endtask

  // =========================================================================
  // Main Task with transaction limit
  // =========================================================================
  task main;
    transaction in_trans, out_trans;
    string operation;
    bit got_transaction;
    int timeout_count = 0;
    int max_timeouts = 5; // Maximum consecutive timeouts before stopping

    fork
      begin
        while (num_transactions < max_transactions && timeout_count < max_timeouts) begin
          // Get transaction with timeout
          got_transaction = 0;
          fork
            begin
              mon_in2scb.get(in_trans);
              got_transaction = 1;
            end
            begin
              #(transaction_timeout);
            end
          join_any
          disable fork;

          if (!got_transaction) begin
            timeout_count++;
            if (timeout_count >= max_timeouts) begin
              $display("[Scoreboard] Max timeouts reached (%0d), stopping test", max_timeouts);
              break;
            end
            continue;
          end
          
          timeout_count = 0; // Reset timeout counter on successful transaction
          num_transactions++;

          // >>> MANUAL COVERAGE SAMPLE <<<
          sample_in_transaction(in_trans);

          // Handle reset
          if (in_trans.rst) begin
            foreach(mem_expected[i]) mem_expected[i] = 8'hFF;
            alu_result_expected = 16'b0;

          // Otherwise handle read/write
          end else begin
            if (in_trans.rd_wr == 0) begin // Write
              handle_write(in_trans);
              check_reserved_bits(in_trans);
              
              // If EXECUTE_REG bit[0] is set => ALU operation
              if (mem_expected[3][0]) begin
                got_transaction = 0;
                fork
                  begin
                    mon_out2scb.get(out_trans);
                    got_transaction = 1;
                  end
                  begin
                    #(transaction_timeout);
                  end
                join_any
                disable fork;
                
                if (got_transaction) begin
                  check_alu_result(out_trans, mem_expected[2][2:0]);
                end
              end

            end else begin // Read
              got_transaction = 0;
              fork
                begin
                  mon_out2scb.get(out_trans);
                  got_transaction = 1;
                end
                begin
                  #(transaction_timeout);
                end
              join_any
              disable fork;
              
              if (got_transaction) begin
                handle_read(in_trans, out_trans);
              end
            end
          end
        end
        
        // Signal test completion
        -> test_done;
      end
    join_none
  endtask

  // =========================================================================
  // ALU result checker
  // =========================================================================
  function void check_alu_result(transaction out_trans, bit [2:0] op_code);
    string op_name;
    case (op_code)
      3'b000: begin 
        alu_result_expected = 16'b0;
        op_name = "NOP";
      end
      3'b001: begin 
        alu_result_expected = mem_expected[0] + mem_expected[1];
        op_name = "ADD";
      end
      3'b010: begin 
        alu_result_expected = mem_expected[0] - mem_expected[1];
        op_name = "SUB";
      end
      3'b011: begin 
        alu_result_expected = mem_expected[0] * mem_expected[1];
        op_name = "MUL";
      end
      3'b100: begin
        if (mem_expected[1] != 0) begin
          alu_result_expected = mem_expected[0] / mem_expected[1];
          op_name = "DIV";
        end else begin
          alu_result_expected = 16'hDEAD;
          op_name = "DIV_0";
        end
      end
      default: begin
        op_name = "INV";
      end
    endcase

    if (out_trans.res_out !== alu_result_expected) begin
      $error("[Scoreboard] ALU %s FAIL E=0x%0h,A=0x%0h",
             op_name, alu_result_expected, out_trans.res_out);
      num_failed++;
    end else begin
      num_passed++;
    end
  endfunction

  // =========================================================================
  // Check reserved bits
  // =========================================================================
  function void check_reserved_bits(transaction trans);
    if (trans.addr == 2 && |trans.wr_data[7:3]) begin
      $error("[Scoreboard] OPER reserved bits: 0x%0h", trans.wr_data[7:3]);
      num_failed++;
    end
    if (trans.addr == 3 && |trans.wr_data[7:1]) begin
      $error("[Scoreboard] EXEC reserved bits: 0x%0h", trans.wr_data[7:1]);
      num_failed++;
    end
  endfunction

  // =========================================================================
  // Display summary
  // =========================================================================
  function void display_summary();
    real pass_rate;
    pass_rate = (num_passed + num_failed) > 0 ? 
                (num_passed * 100.0 / (num_passed + num_failed)) : 0;
    
    $display("\n=== Scoreboard Summary ===");
    $display("Transactions: %0d", num_transactions);
    $display("Pass/Fail: %0d/%0d (%.1f%%)", 
             num_passed, num_failed, pass_rate);
    print_mem_expected(1);
    $display("=========================\n");
  endfunction

endclass
