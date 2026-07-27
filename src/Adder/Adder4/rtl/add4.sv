//==============================================================================
//  Module      : Add4
//  File        : add4.sv
//  Description : 4-bit combinational adder. Computes the sum of two operands
//                with an optional carry input. The result and carry-out are
//                produced combinationally.
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
//      - None
//
//  Ports:
//      ope_a : input  logic [3:0] - first operand
//      ope_b : input  logic [3:0] - second operand
//      c_in   : input  logic       - carry input
//      sum   : output logic [3:0] - addition result
//      c_out  : output logic       - carry output
//
//  License: MIT (see LICENSE file)
//==============================================================================


module Add4 ( 
    input  logic [3:0] ope_a,
    input  logic [3:0] ope_b,
    input  logic       c_in,
    output logic [3:0] sum,
    output logic       c_out
);

    assign {c_out, sum} = ope_a + ope_b + c_in;

endmodule