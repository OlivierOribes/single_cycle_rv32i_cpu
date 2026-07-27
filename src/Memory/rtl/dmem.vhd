--==============================================================================
--  Module      : dmem
--  File        : dmem.vhd
--  Description : Byte-addressed instruction RAM with synchronous write and asynchronous read.
--                - Read and Write operations are synchronous (rising_edge(clk))
--
--  Author      : Olivier
--  Created     : 19/03/2026
--  Last update : 14/08/2026
--
--  Version     : 2.0
--
--  Project     : CPU
--  Language    : VHDL
--
--  Dependencies:
--      - cpu.pkg (to_int and index_size_f functions)
--
--  Generics:
--      DWIDTH : integer - data size in bits(default : 32)
--      ADDR_WIDTH : integer - address size in bits(default : 32)
--      DEPTH  : integer - Number of words in the memory (default : 64)
--
--  Ports:
--      clk         : in  std_logic
--      rw_i        : in  std_logic  0 = read, 1 = write
--      addr_i      : in  std_logic_vector(ADDR_WIDTH-1 downto 0)
--      data_i      : in  std_logic_vector(DWIDTH-1 downto 0)
--      data_o      : out std_logic_vector(DWIDTH-1 downto 0)
--
--  Behavior:
--      - On rising edge of clk:
--          • If rw_i = '1' AND address is aligned :
--              → mem(to_int(addr_i(addr_i(INDEX_BITS + OFFSET_BITS-1 downto OFFSET_BITS)))) <= write_data
--
--      - else (rw_i = '0') Read :
--          • If address is aligned :
--              → read_data =  mem(to_int(addr_i(INDEX_BITS + OFFSET_BITS-1 downto OFFSET_BITS))))
--              → read_data = rdata
--
--  Notes:
--      - Memory is byte-addressed but word-aligned
--      - OFFSET_BITS = log2(real(DWIDTH))): number of LSBs used as byte offset
--      - Misaligned accesses are ignored
--      - No reset on memory (synthesizable FPGA behavior)
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

entity dmem is
    generic (
        DEPTH    : integer := 64;   -- Must be a power of two
        FILENAME : string
    );
    port (
        clk        : in  std_ulogic;
        rst_n      : in  std_ulogic;
        -- read/write port --
        en_i   : in  std_ulogic;                               -- memory access enable
        rw_i   : in  std_ulogic;                               -- 0 = read, 1 = write
        addr_i : in  std_ulogic_vector(ADDR_WIDTH-1 downto 0); -- address
        data_i : in  std_ulogic_vector(DATA_WIDTH-1 downto 0); -- data to write in memory
        data_o : out std_ulogic_vector(DATA_WIDTH-1 downto 0)  -- memory data out
    );
end entity dmem;

architecture rtl of dmem is
            
    -- =========================================================
    -- Constant and signals
    -- ========================================================= 
    constant BYTE_IN_WORD   : integer := (DATA_WIDTH/8);
    constant OFFSET_BITS    : integer := integer(log2(real(BYTE_IN_WORD))); -- Bytes used to move within a word
    constant ALIGN_BITS     : std_ulogic_vector(OFFSET_BITS-1 downto 0) := (others => '0'); -- Used to ensure word alignment
    constant INDEX_BITS     : integer := index_size_f(natural(DEPTH));
    constant HIGH_BITS_ZERO : std_ulogic_vector(ADDR_WIDTH-1 downto INDEX_BITS+OFFSET_BITS) := (others => '0');

    type ram_t is array (DEPTH-1 downto 0) of std_ulogic_vector(DATA_WIDTH-1 downto 0);

    -- Memory initialisation from an external file
    impure function init_memory(
        file_name : string
    ) return ram_t is

        file memory_file : text open read_mode is file_name;

        variable current_line : line;
        variable memory       : ram_t := (others => (others => '0'));
        variable instruction  : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable index        : natural := 0;
    begin

        while not endfile(memory_file) loop

            exit when index >= DEPTH;

            readline(memory_file, current_line);
            hread(current_line, instruction);

            memory(index) := std_ulogic_vector(instruction);

            index := index + 1;

        end loop;

        return memory;

    end function init_memory;

    signal mem : ram_t := init_memory(FILENAME);
    signal rdata : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
begin


    -- =========================================================
    -- Asynchronous read and Synchronous write
    -- =========================================================
    memory_core : process(clk, rst_n)

    begin

        if (rst_n = '0') then

            for i in 0 to (DEPTH-1) loop

                mem(i) <= (others => '0');
            end loop;

        elsif rising_edge(clk) then

            if (en_i = '1') then

                if ((addr_i(OFFSET_BITS - 1 downto 0) = ALIGN_BITS)
                    and (addr_i(ADDR_WIDTH-1 downto INDEX_BITS+OFFSET_BITS) = HIGH_BITS_ZERO)) then -- Check words alignement and valid address

                    if (rw_i = '1') then

                        mem(to_int(addr_i(INDEX_BITS + OFFSET_BITS-1 downto OFFSET_BITS))) <= data_i;

                    end if;

                end if;

            end if;

        end if;

    end process memory_core;
    
    -- Asynchronous read
    rdata <=  mem(to_int(addr_i(INDEX_BITS + OFFSET_BITS-1 downto OFFSET_BITS)));
    data_o <= rdata;


end architecture rtl;