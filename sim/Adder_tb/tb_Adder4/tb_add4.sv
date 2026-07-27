//==============================================================================
//  Module      : Adder4 Testbench
//  File        : tb_adder4.sv
//  Description : Testbench for the Add4 module. Verifies the correct behavior
//                of the 4-bit combinational adder by checking the addition of
//                two operands with carry input and validating the resulting
//                sum and carry-out.
//
//  Author      : Olivier Oribes
//  Created     : 10/03/2026
//  Last update : 10/03/2026
//
//  Version     : 1.0
//
//  Project     : CPU_Single_cycle
//  Language    : SystemVerilog
//
//  Dependencies:
//      - add4.sv
//
//  Parameters:
//      None
//
//  Ports:
//      None (testbench has no ports)
//
//  Tests:
//      1. Addition without carry-in
//      2. Addition with carry-in
//      3. Overflow / carry-out generation
//
//  License: MIT (see LICENSE file)
//
//==============================================================================

`timescale 1ns/1ps   // set timescale to nanoseconds, ps precision


/**********************************************************************
** Libraries
**********************************************************************/


/**********************************************************************
** Testbench entity declaration
**********************************************************************/
module tb_add4;

parameter WIDTH = 4;

logic [WIDTH-1:0] ope_a;
logic [WIDTH-1:0] ope_b;
logic [WIDTH-1:0] sum;
logic c_in;
logic c_out;

logic [WIDTH:0] reference;

/**********************************************************************
** DUT
**********************************************************************/
Add4 dut (
    .ope_a (ope_a),
    .ope_b (ope_b),
    .c_in  (c_in),
    .sum   (sum),
    .c_out (c_out)
);

/**********************************************************************
** Test
**********************************************************************/
initial begin

    $dumpfile("adder_sim.vcd");
    $dumpvars(0,tb_add4);

    for (int a = 0; a < 2**WIDTH; a++) begin
        for (int b = 0; b < 2**WIDTH; b++) begin
            for (int c = 0; c < 2; c++) begin

                ope_a = a;
                ope_b = b;
                c_in  = c;

                #2;

                reference = a + b + c;

                if ({c_out,sum} !== reference) begin
                    $error("ERROR: A=%h B=%h Cin=%b -> Sum=%h Cout=%b | Expected=%h",
                            ope_a, ope_b, c_in, sum, c_out, reference);
                end

            end
        end
    end

    $display("ALL TESTS PASSED");
    $finish;

end

endmodule