--==============================================================================
--  Module      : MUX
--  File        : mux.vhd
--  Description : A simple multiplexer used to choose between two input
--
--
--  Author      : Olivier Oribes
--  Created     : 17/07/2026
--  Last update : 17/07/2026
--
--  Version     : 1.0
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--
--
--  Ports:
--      data_i1      : input data 1
--      data_i2      : input data 2
--      op           : input op code to switch
--      data_o       : output data
--    
--
--  License: MIT (see LICENSE file)
--      
--
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux is 
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        data_i1 : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        data_i2 : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        op      : in std_ulogic;
        data_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
    );

end entity mux;


architecture rtl of mux is
begin

    data_o <= data_i1 when op = '0' else 
              data_i2 when op = '1' else
              (others => 'X');

end architecture rtl;