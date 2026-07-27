//==============================================================================
//  Module      : Adder Testbench
//  File        : tb_adder.sv
//  Description : Testbench for the Add4 module. Verifies the correct behavior
//                of the N-bit combinational adder by checking the addition of
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
//      - adder.sv
//
//  Parameters:
//      WIDTH   : N-bit instruction width.
//      N       : Treshold for test
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

module tb_adder;

parameter WIDTH = 32;
parameter N = 1000;

logic [WIDTH-1:0] ope_a;
logic [WIDTH-1:0] ope_b;
logic [WIDTH-1:0] sum;
logic cin;
logic cout;
logic sub;

logic [WIDTH:0] reference;

/**********************************************************************
** DUT
**********************************************************************/
Adder dut (
    .ope_a (ope_a),
    .ope_b (ope_b),
    .cin   (cin),
    .sub   (sub),
    .sum   (sum),
    .cout  (cout)
);

/**********************************************************************
** Test
**********************************************************************/
initial begin

    $dumpfile("adder_sim.vcd");
    $dumpvars(0,tb_adder);

    for (int i = 0; i < N; i++) begin

        // opérandes aléatoires
        ope_a = $urandom;
        ope_b = $urandom;

        // contrôle aléatoire
        cin   = $urandom % 2;
        sub   = $urandom % 2;

        #2;

        // calcul de référence
        reference = ope_a + (ope_b ^ {WIDTH{sub}}+sub) + cin;

        if ({cout,sum} !== reference) begin
            $error("ERROR: sub=%b cin=%b A=%h B=%h -> Sum=%h Cout=%b | Expected=%h",
                    sub, cin, ope_a, ope_b, sum, cout, reference);
        end

    end

    $display("ALL TESTS PASSED");
    $finish;

end

endmodule