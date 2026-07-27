--==============================================================================
--  Module      : Program Counter
--  File        : program_counter.vhd
--  Description : A simple program counter that stores the address of the next
--                instruction to be executed. The counter updates its value on
--                each clock cycle and provides the instruction address to the
--                instruction memory.
--
--
--  Author      : Olivier Oribes
--  Created     : 09/03/2026
--  Last update : 09/03/2026
--
--  Version     : 1.0
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--
--  Generics:
--      DATA_WIDTH : integer := 32  -- Instruction size (in bits)
--
--  Ports:
--      clk     : in  std_logic                     -- system clock
--      rst_n   : in  std_logic                     -- active-low reset
--      load    : in  std_logic                     -- 1 = jump, 0 = increment
--      pc_in   : in  std_logic_vector(DATA_WIDTH-1 downto 0)  -- jump address (from ALU)
--      pc_out  : out std_logic_vector(DATA_WIDTH-1 downto 0)  -- current instruction address
--
--
--  License: MIT (see LICENSE file)
--
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity program_counter is 
    port (
        clk     : in    std_ulogic;
        rst_n   : in    std_ulogic;
        load    : in    std_ulogic;
        pc_in   : in    std_ulogic_vector(DATA_WIDTH-1 downto 0);
        pc_out  : out   std_ulogic_vector(DATA_WIDTH-1 downto 0)

    );
end entity program_counter;


architecture rtl of program_counter is
    
    signal pc_reg  : std_ulogic_vector(DATA_WIDTH-1 downto 0);
    
begin

    proc_ff: process(clk, rst_n)
    begin 

        if rst_n = '0' then  -- Asynchronous negedge reset

            pc_reg <= (others => '0');
        

        elsif rising_edge(clk) then

            if (load = '1') then

                pc_reg <= pc_in; 

            else 

                pc_reg <= std_ulogic_vector(unsigned(pc_reg) + 4);

            end if;

        end if;
        
    end process proc_ff;
    
    pc_out <= pc_reg;
    
end architecture rtl;



