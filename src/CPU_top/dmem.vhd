--==============================================================================
--  Module      : dmem
--  File        : dmem.vhd
--  Description : Word-organized data RAM with synchronous, per-byte write
--                (via byte_en) and asynchronous read.
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
--      - cpu_pkg (to_int and index_size_f functions, DATA_WIDTH,
--        ADDR_WIDTH, DATA_DEPTH, BYTE_IN_WORD)
--
--  Generics:
--      FILENAME : String - name of the initialization file
--
--  Ports:
--      clk     : in  std_ulogic
--      en_i    : in  std_ulogic                                    - memory access enable
--      rw_i    : in  std_ulogic                                    - 0 = read, 1 = write
--      byte_en : in  std_ulogic_vector(BYTE_IN_WORD-1 downto 0)    - one bit per byte lane to write
--      addr_i  : in  std_ulogic_vector(ADDR_WIDTH-1 downto 0)
--      data_i  : in  std_ulogic_vector(DATA_WIDTH-1 downto 0)
--      data_o  : out std_ulogic_vector(DATA_WIDTH-1 downto 0)
--
--  Behavior:
--      - On rising edge of clk, if en_i = '1' and rw_i = '1' and the address
--        is within range:
--          • For each byte lane b where byte_en(b) = '1' :
--              → data_mem(word_idx)(byte b) <= data_i(byte b)
--          • byte_en = "1111" (full word) additionally requires the address
--            to be word-aligned, otherwise the write is ignored.
--          • byte_en with fewer bits set (SB/SH) needs no such alignment
--            check: the pattern itself only ever selects a valid byte or
--            half-word lane.
--
--      - Else (rw_i = '0'), asynchronous read :
--          • If address is in range and word-aligned :
--              → data_o = data_mem(word_idx)
--          • Otherwise data_o = (others => '0')
--
--  Notes:
--      - Memory is organized as DATA_DEPTH words of DATA_WIDTH bits; byte_en
--        selects which byte lanes of a word are actually written.
--      - OFFSET_BITS = log2(BYTE_IN_WORD): number of address LSBs used to
--        select a byte within a word (not used to index data_mem).
--      - Out-of-range addresses, and misaligned full-word accesses, are
--        ignored on write and read as zero.
--      - rst_n asynchronously clears the whole memory array (not a "no
--        reset" FPGA-style RAM).
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
        FILENAME : string
    );
    port (
        clk        : in  std_ulogic;
        -- read/write port --
        en_i    : in  std_ulogic;                                    -- memory access enable
        rw_i    : in  std_ulogic;                                    -- 0 = read, 1 = write
        byte_en : in  std_ulogic_vector(BYTE_IN_WORD - 1 downto 0);  -- Enable byte in a word
        addr_i  : in  std_ulogic_vector(ADDR_WIDTH-1 downto 0);      -- address
        data_i  : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);      -- data to write in memory
        data_o  : out std_ulogic_vector(DATA_WIDTH-1 downto 0)       -- memory data out
    );
end entity dmem;

architecture rtl of dmem is
            
    -- =========================================================
    -- Constant and signals
    -- ========================================================= 
    constant OFFSET_BITS    : integer := integer(log2(real(BYTE_IN_WORD))); -- Bytes used to move within a word
    constant ALIGN_BITS     : std_ulogic_vector(OFFSET_BITS-1 downto 0) := (others => '0'); -- Used to ensure word alignment
    constant INDEX_BITS     : integer := index_size_f(natural(DATA_DEPTH));
    constant HIGH_BITS_ZERO : std_ulogic_vector(ADDR_WIDTH-1 downto INDEX_BITS+OFFSET_BITS) := (others => '0');

    -- Memory initialisation from an external file
    impure function init_memory(
        file_name : string
    ) return dmem_ram_t is

        file memory_file : text open read_mode is file_name;

        variable current_line : line;
        variable memory       : dmem_ram_t := (others => (others => '0'));
        variable instruction  : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable index        : natural := 0;
    begin

        while not endfile(memory_file) loop

            exit when index >= DATA_DEPTH;

            readline(memory_file, current_line);
            hread(current_line, instruction);

            memory(index) := std_ulogic_vector(instruction);

            index := index + 1;

        end loop;

        return memory;

    end function init_memory;

    signal data_mem   : dmem_ram_t := init_memory(FILENAME);
    signal rdata      : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal valid_addr : std_ulogic;

begin

    valid_addr <=  '1' when (((addr_i(OFFSET_BITS - 1 downto 0) = ALIGN_BITS) or (byte_en /= "1111")) 
                   and addr_i(ADDR_WIDTH - 1 downto INDEX_BITS + OFFSET_BITS) = HIGH_BITS_ZERO)
                   else '0';

    -- =========================================================
    -- Asynchronous read and Synchronous write
    -- =========================================================
    memory_core : process(clk)
    
        variable word_idx   :  integer;

    begin
        
        if rising_edge(clk) then

            if (((en_i = '1') and (rw_i = '1'))       -- Memory block enable and write enable
               and valid_addr = '1') then             -- Full word must be aligned

                word_idx := to_int(addr_i(INDEX_BITS + OFFSET_BITS-1 downto OFFSET_BITS));

                for b in 0 to (BYTE_IN_WORD - 1) loop
                    
                    if (byte_en(b) = '1') then

                        data_mem(word_idx)((b + 1)*BYTE_WIDTH - 1 downto b*BYTE_WIDTH)  <= data_i((b + 1)*BYTE_WIDTH - 1 downto b*BYTE_WIDTH);

                    end if;

                end loop;

            end if;

        end if;

    end process memory_core;
    
    -- Asynchronous read
    rdata <= data_mem(to_int(addr_i(INDEX_BITS + OFFSET_BITS - 1 downto OFFSET_BITS)))
             when (
             (en_i = '1' and rw_i = '0') and
             valid_addr = '1')
             else (others => '0');

    data_o <= rdata;


end architecture rtl;