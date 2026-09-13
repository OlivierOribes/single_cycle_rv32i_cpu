--==============================================================================
--  Module      : imem
--  File        : imem.vhd
--  Description : Byte-addressed instruction RAM with synchronous write and asynchronous read.
--
--  Author      : Olivier
--  Created     : 19/03/2026
--  Last update : 02/09/2026
--
--  Version     : 2.1
--
--  Project     : CPU
--  Language    : VHDL
--
--  Dependencies:
--      - cpu.pkg (to_int and index_size_f functions)
--
--  Generics:
--      FILENAME : String - name of the initialization file

--
--  Ports:
--      clk         : in  std_ulogic
--      rst_n       : in  std_ulogic                                - asynchronous reset, clears memory
--      en_i        : in  std_ulogic                                - memory access enable
--      rw_i        : in  std_ulogic  0 = read, 1 = write
--      addr_i      : in  std_ulogic_vector(ADDR_WIDTH-1 downto 0)
--      data_i      : in  std_ulogic_vector(DATA_WIDTH-1 downto 0)
--      data_o      : out std_ulogic_vector(DATA_WIDTH-1 downto 0)
--
--  Behavior:
--      - On rising edge of clk, if rst_n = '0': whole memory cleared to zero.
--      - Else, if en_i = '1' and rw_i = '1' and address is word-aligned :
--              → mem(word_idx) <= data_i
--
--      - Asynchronous read : data_o = mem(word_idx) only when en_i = '1',
--        rw_i = '0', and the address is in range and word-aligned;
--        otherwise data_o = (others => '0').
--
--  Notes:
--      - Memory is byte-addressed but word-aligned (INST_DEPTH words of
--        DATA_WIDTH bits)
--      - OFFSET_BITS = log2(BYTE_IN_WORD): number of LSBs used as byte offset
--      - Misaligned or out-of-range accesses are ignored on write and read
--        as zero
--      - rst_n asynchronously clears the whole memory array
--
--  License: MIT
--==============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_textio.all;
use work.cpu_pkg.all;

library std;
use std.textio.all;

entity imem is
    generic (
        FILENAME  : string
    );
    port (

        addr_i : in  std_ulogic_vector(ADDR_WIDTH-1 downto 0); -- address
        data_o : out std_ulogic_vector(DATA_WIDTH-1 downto 0)  -- memory data out
    );
end entity imem;

architecture rtl of imem is

      
    -- =========================================================
    -- Constant and signals
    -- ========================================================= 
    constant BYTE_IN_WORD   : integer := (DATA_WIDTH/8);
    constant OFFSET_BITS    : integer := integer(log2(real(BYTE_IN_WORD))); -- Bytes used to move within a word
    constant ALIGN_BITS     : std_ulogic_vector(OFFSET_BITS-1 downto 0) := (others => '0'); -- Used to ensure word alignment
    constant INDEX_BITS     : integer := index_size_f(natural(INST_DEPTH));
    constant HIGH_BITS_ZERO : std_ulogic_vector(ADDR_WIDTH-1 downto INDEX_BITS+OFFSET_BITS) := (others => '0');

    -- Memory initialisation from an external file
    impure function init_memory(
        file_name : string
    ) return imem_ram_t is

        file memory_file : text open read_mode is file_name;

        variable current_line : line;
        variable memory       : imem_ram_t := (others => (others => '0'));
        variable instruction  : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable index        : natural := 0;
    begin

        while not endfile(memory_file) loop

            exit when index >= INST_DEPTH;

            readline(memory_file, current_line);
            hread(current_line, instruction);

            memory(index) := std_ulogic_vector(instruction);

            index := index + 1;
             
        end loop;

        return memory;

    end function init_memory;

    signal mem : imem_ram_t := init_memory(FILENAME);
    signal rdata : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal valid_addr : std_ulogic;

    attribute rom_style : string;
    attribute rom_style of mem : signal is "block";

begin
    
    valid_addr <= '1' when (addr_i(OFFSET_BITS - 1 downto 0) = ALIGN_BITS
                      and addr_i(ADDR_WIDTH - 1 downto INDEX_BITS + OFFSET_BITS) = HIGH_BITS_ZERO)
                      else '0';

    -- Asynchronous read
    rdata <= mem(to_int(addr_i(INDEX_BITS + OFFSET_BITS-1 downto OFFSET_BITS)))
             when (valid_addr = '1')
             else (others => '0');

    data_o <= rdata;


end architecture rtl;