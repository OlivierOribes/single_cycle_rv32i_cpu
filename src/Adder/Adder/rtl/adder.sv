//==============================================================================
//  Module      : Adder
//  File        : adder.sv
//  Description : Parameterizable adder performing an addition between two
//                operands. The result and carry-out are produced combinationally.
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
//  Parameters:
//      WIDTH : Operand size (in bits)
//
//  Ports:
//      ope_a : input  logic [WIDTH-1:0]   - first operand
//      ope_b : input  logic [WIDTH-1:0]   - second operand
//      cin  : input  logic                - carry input
//      sum   : output logic [WIDTH-1:0]   - addition result
//      cout : output logic                - carry output
//
//  License: MIT (see LICENSE file)
//============================================================================== 


module Adder #(
    parameter int WIDTH = 32
)( 
    input logic [WIDTH-1:0] ope_a,               	
    input logic [WIDTH-1:0] ope_b, 
    input logic cin,
    input logic sub,		
    output logic [WIDTH-1:0] sum,
    output logic cout
);


    assign {cout, sum} = ope_a + (ope_b^{WIDTH{sub}}+sub) + cin;

endmodule