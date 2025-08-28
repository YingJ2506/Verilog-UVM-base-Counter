// ===================
// Counter main module
// ===================
module counter_dut #(
    parameter WIDTH = 8
)(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic mode,
    output logic [WIDTH-1:0] count_out
);
    localparam MAX_COUNT = (2**WIDTH) - 1; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_out <= 0;
        end
        else begin
            if (en == 1) begin
                if (mode == 1) begin
                    count_out <= (count_out == MAX_COUNT) ? 0 : count_out + 1;
                end else begin
                    count_out <= (count_out == 0) ? MAX_COUNT : count_out - 1;
                end
            end
        end
    end
endmodule

// ===============
// Interface block
// ===============

module counter_interface #(
    parameter WIDTH = 8
)(
    input logic clk,
    input logic rst_n,
    output logic en,
    output logic mode,
    input logic [WIDTH-1:0] count_out
);


endmodule

// =================
// Transaction block
// =================

module counter_transaction;
    // data store
    logic trans_en [0:255];     // enable
    logic trans_mode [0:255];   // mode 
    logic trans_id [0:255];      // local trans_id
    
    integer current_trans_id;   // global trans_id
    
    initial begin
        current_trans_id = 0;
    end
    
    // as randomize()
    task automatic create_random_transaction(output integer trans_id);
        trans_id = current_trans_id;
        trans_en[trans_id] = $urandom % 2;
        trans_mode[trans_id] = $urandom % 2;
        current_trans_id = current_trans_id + 1;
        $display("[TRANSACTION] Created trans_id=%d, en=%d, mode=%d", 
                trans_id, trans_en[trans_id], trans_mode[trans_id]);
    endtask

    // for get transaction
    task automatic get_transaction(output integer trans_id, output logic [15:0] en, output logic [15:0] mode);
        create_random_transaction(trans_id);
        en = trans_en[trans_id];
        mode = trans_mode[trans_id];
    endtask

endmodule

// ============
// Driver block
// ============

module counter_driver(
    input logic clk,
    input logic rst_n,
    output logic en,
    output logic mode,
  
    input logic start_driving,
    output logic driving_done
);
    integer trans_id;
    logic [15:0] local_en, local_mode;
    
    // Driver job
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en <= 0;
            mode <= 0;
            driving_done <= 0;
        end
        else begin
            if (start_driving == 1 && driving_done == 0) begin
                // from transaction pool get data
                top_tb.trans_pool.get_transaction(trans_id, local_en, local_mode);

                // Drive signals - as UVM driver -- drive_item            
                en <= local_en;
                mode <= local_mode;
                $display("[DRIVER] @%0t Driving trans_id=%0d: en=%d, mode=%d", 
                        $time, trans_id, local_en, local_mode);
                
                driving_done <= 1;
            end
            else begin
                driving_done <= 0;
            end
        end
    end
endmodule

// =============
// Monitor block
// =============

module counter_monitor(
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic mode,
    input logic [7:0] count_out,
    input logic monitoring_enable
);
    logic en_dly, mode_dly;
    logic [7:0] count_out_dly;    

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_dly <= 0;
            mode_dly <= 0;
            count_out_dly <= 0;
        end else begin
            en_dly <= en;
            mode_dly <= mode;
            count_out_dly <= count_out;
        end
    end

    // Monitor data collection
    always_ff @(posedge clk) begin
        if (rst_n && monitoring_enable) begin
            $display("[MONITOR] @%0t Observed: en=%d, mode=%d, count_out=%0d", 
                    $time, en_dly, mode_dly, count_out_dly);
            
            // trans to scoreboard
            top_tb.scoreboard.add_observed_data(en_dly, mode_dly, count_out_dly);
        end
    end
    
endmodule

// ==============
// Sequence block
// ==============

module counter_sequence(
    input logic clk,
    input logic rst_n,
    input logic start_sequence,
    output logic sequence_done,
    output logic start_driving,
    input logic driving_done
);
    integer seq_count;
    integer max_sequences;
    
    initial begin
        sequence_done = 0;
        start_driving = 0;
        seq_count = 0;
        max_sequences = 15;  // as repeat(15)
        wait(rst_n);
        repeat(2) @(posedge clk);
        // ensure start_driving is low before start
        @(posedge clk) start_driving <= 0; // sequentail control in next posedge clk
        
        // UVM sequence body() task
        while (seq_count < max_sequences) begin
            @(posedge clk) start_driving <= 1;
            $display("[SEQUENCE] Starting sequence %0d/%0d", seq_count+1, max_sequences);

            wait(driving_done == 1);

            @(posedge clk) start_driving <= 0;
            seq_count = seq_count + 1; 
        end
        // when out of while => finish
        @(posedge clk) sequence_done <= 1;
        $display("[SEQUENCE] All sequences completed");        
    end
    
endmodule

// ================
// Scoreboard block
// ================

module counter_scoreboard;
    
    logic [7:0] expected_count;
    logic [7:0] actual_count;
    logic last_mode, last_en;
    logic [7:0] last_count;
    integer pass_count, fail_count;
    
    initial begin
        expected_count = 0;
        pass_count = 0;
        fail_count = 0;
        last_mode = 0; // default in down count
        last_en = 0;
        last_count = 0;
    end
    
    // check add observed data
    task automatic add_observed_data(input logic obs_en, input logic obs_mode, input logic [7:0] obs_count);
        //  step1: predict
        if (last_en == 1) begin
            if (last_mode == 1) begin
                expected_count = (last_count == 255) ? 0 : last_count + 1;
            end else begin
                expected_count = (last_count == 0) ? 255 : last_count - 1;
            end
        end else begin  // en == 0
            expected_count = last_count;
        end

        // step2: check
        if (obs_en == 1 && last_en == 0) begin // en from 0 to 1
            
            actual_count = obs_count;
            if (actual_count == expected_count) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("[SCOREBOARD] At %0t FAILED| Expected:%0d, Actual:%0d",$time, expected_count, actual_count);
            end
        end else if (obs_en == 1) begin // en keep 1 
            actual_count = obs_count;
            if (actual_count == expected_count) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("[SCOREBOARD] At %0t FAILED| Expected:%0d, Actual:%0d",$time, expected_count, actual_count);
            end
        end else begin  // keep 0, no action
            actual_count = obs_count;
        end

        // step3: update
        last_en = obs_en;
        last_mode = obs_mode;
        last_count = obs_count;
    endtask
    
    // final report
    task automatic final_report();
        if (fail_count == 0)
           $display("[SCOREBOARD FINAL REPORT] === TEST PASSED === PASS COUNT: %0d", pass_count);
        else 
           $display("[SCOREBOARD FINAL REPORT] === TEST FAILED === FAIL COUNT: %0d", fail_count);
    endtask
endmodule

// =================
// Environment block
// =================

module counter_environment(
    input logic clk,
    input logic rst_n,
    output logic en,
    output logic mode,
    input logic [7:0] count_out
);
    
    // Environment components - as UVM env build_phase
    logic start_seq, seq_done, start_drv, drv_done;
    logic mon_enable;
  
    // control start_seq and mon_ebable
    logic start_seq_ctrl, mon_enable_ctrl;
  
    assign start_seq = start_seq_ctrl;
    assign mon_enable = mon_enable_ctrl;
    
    // instance sequence (as sequencer)
    counter_sequence seq_inst(
        .clk(clk),
        .rst_n(rst_n), 
        .start_sequence(start_seq),
        .sequence_done(seq_done),
        .start_driving(start_drv),
        .driving_done(drv_done)
    );
    
    // instance driver
    counter_driver drv_inst(
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .mode(mode),
        .start_driving(start_drv),
        .driving_done(drv_done)
    );
    
    // instance monitor
    counter_monitor mon_inst(
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .mode(mode),
        .count_out(count_out),
        .monitoring_enable(mon_enable)
    );
    
    // Environment control logic - as UVM phases
    initial begin
        mon_enable_ctrl = 0;
        start_seq_ctrl = 0;
        
        // run phase
        wait(rst_n);
        repeat(2) @(posedge clk);
        
        $display("[ENV] Starting test environment...");
        mon_enable_ctrl = 1;
        start_seq_ctrl = 1;
        // start_seq = 1 & mon_enable = 1, start sequence & monitor
        wait(seq_done); // finish 
        mon_enable_ctrl = 0;
        start_seq_ctrl = 0;        

        repeat(10) @(posedge clk); 
        $display("[ENV] Test environment completed");
        
        // extract_phase & check_phase & report_phase
        top_tb.scoreboard.final_report();
    end
    
endmodule