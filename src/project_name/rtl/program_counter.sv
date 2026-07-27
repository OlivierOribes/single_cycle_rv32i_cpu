//==============================================================================
//  Module      : Program Counter 
//  File        : program_counter.sv
//  Description : A simple program counter that stores the address of the next
//                instruction to be executed. The counter updates its value on
//                each clock cycle and provides the instruction address to the
//                instruction memory.
//
//
//  Author      : Olivier Oribes
//  Created     : 09/03/2026
//  Last update : 09/03/2026
//
//  Version     : 1.0
//
//  Project     : CPU_Single_cycle
//  Language    : SystemVerilog
//
//  Dependencies:
//      - <dependency_1>
//      - <dependency_2>
//
//  Parameters:
//      WIDTH : Instruction size (in bits)
//
//  Ports:
//      clk     : input                     - system clock
//      rst_n   : input                     - active-low reset
//      load    : input                     - 1 = jump, 0 = 
//      pc_in   : input logic [WIDTH-1:0]   - Jump adress (come from ALU)
//      pc_out  : output logic [WIDTH-1:0]  - current instruction address
//
//  
//    
//
//  License: MIT (see LICENSE file)
//      
//
//==============================================================================

