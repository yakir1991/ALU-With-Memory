`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Environment class
// Instantiates all testbench components and coordinates the run
// -----------------------------------------------------------------------------
class environment;

  // Virtual interface
  virtual mem_if vif;

  // Components
  generator gen;
  driver drv;
  monitor_in mon_in;
  monitor_out mon_out;
  scoreboard scb;

  // Mailboxes for communication between components
  mailbox gen2drv;
  mailbox mon_in2scb;
  mailbox mon_out2scb;

  // Configuration parameters
  int transaction_count;    // Number of transactions to generate
  int transaction_timeout;  // Timeout value for each transaction
  event test_done;          // Event to signal test completion
  bit  test_complete;       // Flag raised when too many timeouts occur

  // Constructor
  function new(virtual mem_if vif);
    // Get interface from test
    this.vif = vif;
    
    // Create mailboxes
    gen2drv = new();
    mon_in2scb = new();
    mon_out2scb = new();
    
    // Create components
    gen = new(gen2drv);
    drv = new(vif, gen2drv);
    mon_in = new(vif, mon_in2scb);
    mon_out = new(vif, mon_out2scb);
    scb = new(mon_in2scb, mon_out2scb);

    // Set default values
    transaction_count = 100;  // Default number of transactions
    transaction_timeout = 5000;  // Default timeout in ns
  endfunction

  // Task for pre-test initialization
  task pre_test();
    $display("[Environment] Starting pre-test initialization at %0t", $time);
    
    // Configure components
    gen.repeat_count = transaction_count;
    scb.max_transactions = transaction_count;
    scb.transaction_timeout = 50;  // Shorter timeout for scoreboard
    
    // Perform initial reset
    drv.reset();
    
    // Allow some time for reset to propagate
    repeat(5) @(posedge vif.clk);
    
    $display("[Environment] Pre-test initialization completed at %0t", $time);
  endtask

  // Task to monitor generator/scoreboard completion with a timeout mechanism.
  // The timeout branch waits in a loop, incrementing `timeout_count` each time
  // `transaction_timeout` cycles pass without either completion event.  If the
  // count reaches `max_timeouts`, the test is flagged as complete due to
  // excessive timeouts.
  task monitor_completion();
    int timeout_count = 0;
    int max_timeouts  = 5;   // Maximum consecutive timeouts allowed
    bit done = 0;
    fork
      begin
        // Wait for generator to complete
        wait(gen.repeat_count == drv.num_transactions);
        $display("[Environment] Generator completed at %0t", $time);
        done = 1;
      end
      begin
        // Wait for scoreboard to complete
        @(scb.test_done);
        $display("[Environment] Scoreboard completed at %0t", $time);
        done = 1;
      end
      begin
        // Timeout monitoring loop
        // Keep waiting until either completion occurs or too many timeouts
        while (!done && timeout_count < max_timeouts) begin
          repeat(transaction_timeout) @(posedge vif.clk);
          if (!done) begin
            timeout_count++;
            $display("[Environment] Timeout %0d at %0t", timeout_count, $time);
          end
        end
      end
    join_any
    disable fork;

    // Assert completion when the maximum number of timeouts was hit
    if (timeout_count >= max_timeouts && !done) begin
      test_complete = 1;
      $display("[Environment] Test timeout after %0d attempts at %0t", timeout_count, $time);
    end
  endtask

  // Task for post-test cleanup
  task post_test();
    $display("[Environment] Starting post-test cleanup at %0t", $time);
    
    // Wait for last transactions to complete
    repeat(10) @(posedge vif.clk);
    
    // Check component status
    $display("[Environment] Generator transactions: %0d", gen.repeat_count);
    $display("[Environment] Driver transactions: %0d", drv.num_transactions);
    $display("[Environment] Scoreboard transactions: %0d", scb.num_transactions);
    
    // Display final test results
    scb.display_summary();
    
    // Check for test success
    if (scb.num_failed == 0 && drv.num_transactions == transaction_count) begin
      $display("[Environment] ============= TEST PASSED =============");
    end else begin
      $display("[Environment] ============= TEST FAILED =============");
      if (scb.num_failed > 0) begin
        $display("[Environment] Failed transactions: %0d", scb.num_failed);
      end
      if (drv.num_transactions != transaction_count) begin
        $display("[Environment] Incomplete transactions: Expected=%0d, Got=%0d",
                 transaction_count, drv.num_transactions);
      end
    end
    
    -> test_done;  // Signal test completion
    $display("[Environment] Post-test cleanup completed at %0t", $time);
    $finish;  // End the simulation once cleanup is done
  endtask

  // Task to start all components
  task start();
    $display("[Environment] Starting test components at %0t", $time);
    fork
      gen.main();
      drv.main();
      mon_in.main();
      mon_out.main();
      scb.main();
    join_none
  endtask

  // Main task to run the test
  task run();
    $display("[Environment] Starting test execution at %0t", $time);
    
    pre_test();    // Initialize test
    start();       // Start components
    
    fork
      monitor_completion();  // Monitor for completion
      begin
        // Wait for either test_done event or timeout
        fork
          @(test_done);
          begin
            repeat(transaction_timeout * 2) @(posedge vif.clk);
            $display("[Environment] Global timeout reached at %0t", $time);
          end
        join_any
        disable fork;
      end
    join
    
    post_test();   // Cleanup and display results
    
    $display("[Environment] Test execution completed at %0t", $time);
  endtask

endclass
