`timescale 1ns/1ps

module top_tb #(
    parameter WIDTH = 8
);
    logic clk;
    logic rst_n;
    logic en;
    logic mode;
    logic [WIDTH-1:0]count_out;

    // instance DUT
    counter_dut dut(.clk(clk),
                    .rst_n(rst_n),
                    .en(en),
                    .mode(mode),
                    .count_out(count_out)
    );
    // instance environment
    counter_environment env(.clk(clk),
                            .rst_n(rst_n),
                            .en(en),
                            .mode(mode),
                            .count_out(count_out)
    );  
  
    // Transaction pool (as factory)
    counter_transaction trans_pool();
    
    // Scoreboard
    counter_scoreboard scoreboard();
 
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top_tb);
        $display("---Start TEST---");

        clk = 0;
        rst_n = 0;
        repeat(2) @(posedge clk);
      
        rst_n = 1;
        repeat(2) @(posedge clk);
      
        wait(env.seq_done);

        repeat(10) @(posedge clk);
        $display("---End TEST---");
        $finish;
    end

    // Clock generation
    always #5 clk = ~clk;


endmodule