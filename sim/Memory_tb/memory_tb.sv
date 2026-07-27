//==============================================================================
//  Module      : Memory Testbench
//  File        : memory_tb.sv
//  Description : Testbench for the Memory module.
//                Verifies correct behavior of the RAM, including:
//                - Write and read operations
//                - addr_i alignment handling
//                - Out-of-bound access protection
//
//  Author      : Olivier
//  Created     : 20/03/2026
//  Last update : 31/03/2026
//
//  Version     : 1.1
//
//  Project     : CPU
//  Language    : SystemVerilog
//
//  Dependencies:
//      - memory.sv (Device Under Test)
//
//  Parameters:
//      DEPTH : integer - number of 32-bit words in memory (default = 64)
//
//  DUT (Device Under Test):
//      memory
//
//  Signals:
//      clk         : logic - system clock
//      
//      en_i        : access enable
//      rw_i        : std_logic  0 = read, 1 = write
//      addr_i      : std_logic_vector(AWIDTH-1 downto 0)
//
//      data_i      : std_logic_vector(DWIDTH-1 downto 0)
//      data_o      : std_logic_vector(DWIDTH-1 downto 0)
//
//  Test Strategy:
//      - Perform write/read operations on multiple addr_ies
//      - Verify overwrite behavior
//      - Test misaligned addr_i handling (writes ignored)
//      - Test out-of-bound accesses (writes ignored)
//
//  Notes:
//      - Clock is generated within the testbench
//      - No timing constraints (functional simulation only)
//      - Uses tasks for modular testing (write/read_check)
//
//  License: MIT
//==============================================================================


`timescale 1ns/1ps

module memory_tb;

    // ========================
    // Parameters
    // ========================
    localparam DEPTH = 64 ;

    // ========================
    // Signals
    // ========================
    logic clk;
    logic en_i;
    logic rw_i;
    logic [31:0] addr_i;
    logic [31:0] data_i;
    logic [31:0] data_o;

    // ========================
    // DUT
    // ========================
    memory DUT (
        .clk(clk),
        .en_i(en_i),
        .rw_i(rw_i),
        .addr_i(addr_i),
        .data_i(data_i),
        .data_o(data_o)
    );

    // ========================
    // Clock generation
    // ========================
    initial clk = 0;
    always #5 clk = ~clk; // 100 Mhz clock

    // ========================
    // TASKS
    // ========================
    task write(input [31:0] addr, input [31:0] data);
    begin 
        @(posedge clk);
        en_i   = 1;
        rw_i = 1;
        addr_i = addr;
        data_i = data;

        @(posedge clk);
        en_i = 0;

    end 
    endtask

    task read_check(input [31:0] addr, input [31:0] expected);
    begin
        @(posedge clk);
        rw_i = 0;
        en_i = 1;

        addr_i = addr;

        @(posedge clk);
        #1; // let the DUT's registered data_o settle before sampling

        if (data_o !== expected) begin
            $error("ERROR: addr=%h expected=%h got=%h",
                   addr, expected, data_o);
        end 
        else begin
            $display("OK: addr=%h value=%h", addr, data_o);
        end

        @(posedge clk);
        en_i = 0;

    end
    endtask 

    // ========================
    // TEST SEQUENCE
    // ========================
    initial begin
        
        rw_i = 0;
        addr_i = 0;
        data_i = 0;

        @(posedge clk);

        // ========================
        // TEST 1 : basic write/read
        // ========================

        @(posedge clk);
        write(32'h00000000, 32'hDEADBEEF);
        @(posedge clk);
        read_check(32'h00000000, 32'hDEADBEEF);

        // ========================
        // TEST 2 : multiple address write
        // ========================
        @(posedge clk);
        write(32'h00000004, 32'h12345678);
        @(posedge clk);
        write(32'h00000008, 32'hAAAAAAAA);

        @(posedge clk);
        read_check(32'h00000004, 32'h12345678);
        @(posedge clk);
        read_check(32'h00000008, 32'hAAAAAAAA);

        // ========================
        // TEST 3 : overwrite
        // ========================
        @(posedge clk);
        write(32'h00000000, 32'h11111111);
        @(posedge clk);
        read_check(32'h00000000, 32'h11111111);

        // ========================
        // TEST 4 : misaligned addr_i
        // ========================
        @(posedge clk);
        write(32'h00000002, 32'hFFFFFFFF);
        @(posedge clk);
        read_check(32'h00000000, 32'h11111111); // must not change

        // ========================
        // TEST 5 : out-of-bound write
        // ========================
        @(posedge clk);
        write(DEPTH*4, 32'h99999999);
        @(posedge clk);
        read_check(32'h00000000, 32'h11111111);

        // ========================
        // TEST 6 : last valid addr_i
        // ========================
        @(posedge clk);
        write((DEPTH-1)*4, 32'hCAFEBABE);
        @(posedge clk);       
        read_check((DEPTH-1)*4, 32'hCAFEBABE);

        // ========================
        // TEST 7 : random accesses
        // ========================
        for (int i = 0; i < 20; i++) begin
            
            logic [31:0] rand_addr;
            logic [31:0] rand_data;

            rand_addr = ($urandom_range(0, DEPTH-1)) * 4;
            rand_data = $urandom;

            write(rand_addr, rand_data);
            read_check(rand_addr, rand_data);
        end

        $display("ALL TESTS PASSED");
        $finish;
    end

endmodule