--==============================================================================
--  Module      : Register File
--  File        : register_file.vhd
--  Description : 32-register file for RISC-V architecture.
--                - Contains 32 general-purpose registers (x0 to x31)
--                - Register x0 is hardwired to zero (writes are ignored)
--                - Two asynchronous read ports (rs1, rs2)
--                - One synchronous write port (rd)
--
--                Behavior:
--                - Read data is available combinationally
--                - Write occurs on rising clock edge when write_enable = '1'
--                - Writes to x0 are ignored
--
--  Author      : Olivier Oribes
--  Created     : 25/03/2026
--  Last update : 30/03/2026
--
--  Version     : 1.1
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--  Dependencies:
--      - register_file_pkg
--      - RISC-V base ISA instruction format
--
--  Parameters:
--      WIDTH : Register width (default: 32 bits)
--
--  Ports:
--      clk          : input                      - system clock
--      rst_n        : input                      - active-low reset
--      write_enable : input                      - register write enable
--      rs1          : input  [4:0]               - source register 1
--      rs2          : input  [4:0]               - source register 2
--      rd           : input  [4:0]               - destination register
--      write_data   : input  [WIDTH-1:0]         - data to be written into rd
--      rs1_data_o     : output [WIDTH-1:0]         - data read from rs1
--      rs2_data_o     : output [WIDTH-1:0]         - data read from rs2
--
--  License     : MIT (see LICENSE file)
--==============================================================================
library work;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity register_file is
    port (
        clk          : in  std_ulogic;
        rst_n        : in  std_ulogic; -- asynchronous active-low reset

        -- Writes
        write_enable : in  std_ulogic;
        rd           : in  std_ulogic_vector(4 downto 0);                 -- destination register for write_data
        write_data   : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);      -- data to write

        -- Reads
        rs1_i            : in  std_ulogic_vector(4 downto 0);             -- source register 1
        rs2_i            : in  std_ulogic_vector(4 downto 0);             -- source register 2
        rs1_data_o       : out std_ulogic_vector(DATA_WIDTH-1 downto 0);  -- read data port 1
        rs2_data_o       : out std_ulogic_vector(DATA_WIDTH-1 downto 0)   -- read data port 2
    );
end entity register_file;

architecture rtl of register_file is

    type reg_array is array (0 to 31) of std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal regfile : reg_array := (others => (others => '0'));

begin

    -- Synchronous write port with active-low reset
    proc_ff : process(clk, rst_n)
    begin

        if rst_n = '0' then

            for i in 0 to 31 loop

                regfile(i) <= (others => '0');
            end loop;
        
        elsif rising_edge(clk) then

            if (write_enable = '1') and (rd /= "00000") then  -- x0 hardwired to zero, ignore writes
                    
                regfile(to_int(rd)) <= write_data;

            end if;
        end if;
        
    end process proc_ff;

    -- Asynchronous read ports
    rs1_data_o <= regfile(to_int(rs1_i));
    rs2_data_o <= regfile(to_int(rs2_i));

end architecture rtl;