// -----------------------------------------------------------------------------
// Randomized test program
// Creates the environment and kicks off the run
// -----------------------------------------------------------------------------
program test(mem_if vif);

  // Declare environment instance
  environment env;

  // Initial block to run the test
  initial begin
    // Create the environment
    env = new(vif);

    // Set the repeat count of the generator (number of transactions to generate)
    env.transaction_count = 150; 

    // Run the environment
    env.run();
  end

endprogram
