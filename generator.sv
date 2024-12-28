class generator;
  // Declare a transaction object
  rand transaction trans;
  
  // Repeat count indicates the number of transactions to generate
  int repeat_count;
  
  // Mailbox to send the transactions to the driver
  mailbox gen2drv;
  
  // Constructor
  // This function initializes the generator class with a mailbox.
  function new(mailbox gen2drv);
    // Get the mailbox handle from the environment 
    this.gen2drv = gen2drv;
    trans = new(); // Create transaction object
  endfunction
  
  // Main task to generate transactions and send them to the driver
  task main();
    // Verify repeat_count is set
    if (repeat_count <= 0) begin
      $fatal("[Generator] repeat_count must be positive non-zero value!"); // Ensure repeat_count is positive
    end
    
    $display("[Generator] Starting to generate %0d transactions", repeat_count); // Display the number of transactions to generate
    
    repeat (repeat_count) begin
      trans = new(); // Create a new transaction object
      
      // Randomize the transaction and ensure that all constraints pass
      if (!trans.randomize()) begin
        $fatal("[Generator] Transaction randomization failed!"); // Fatal error if randomization fails
      end
      
      // Add additional coverage for operation codes when writing to OPERATION_REG
      if (trans.addr == 2 && trans.rd_wr == 0) begin
        $display("[Generator] Generated Operation Code: %0d", trans.wr_data[2:0]); // Display the operation code
      end
      
      // Add coverage for EXECUTE bit when writing to EXECUTE_REG
      if (trans.addr == 3 && trans.rd_wr == 0) begin
        $display("[Generator] Generated Execute Bit: %0b", trans.wr_data[0]);
      end
      
      // Display the transaction for debugging
      trans.display("[Generator]");
      
      // Send the transaction to the driver via the mailbox
      gen2drv.put(trans); 
      
      // Add small delay between transactions for better timing
      #5;
    end
    
    $display("[Generator] Completed generating %0d transactions", repeat_count);
  endtask

endclass