--==============================================================================
--  Package     : cpu_pkg
--  File        : cpu_pkg.vhd
--  Description : Project-wide shared package for the CPU_Single_cycle project.
--                Contains common constants, type definitions, and utility
--                functions used across all modules and testbenches.
--
--  Author      : Olivier Oribes
--  Created     : 29/03/2026
--  Last update : 29/03/2026
--
--  Version     : 1.0
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--  License     : MIT (see LICENSE file)
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cpu_pkg is

    --------------------------------------------------------------------------
    -- Architecture constants
    --------------------------------------------------------------------------
    constant DATA_WIDTH  : integer := 32;   -- Data bus width (bits)
    constant ADDR_WIDTH  : integer := 32;   -- Address bus width (bits)

    --------------------------------------------------------------------------
    -- Common subtypes
    --------------------------------------------------------------------------

    type alu_op_t is (
        ALU_NOP,
        ALU_ADD,
        ALU_SUB,
        ALU_AND,
        ALU_OR,
        ALU_XOR,
        ALU_SLL,
        ALU_SRL,
        ALU_SLT
    );

    --------------------------------------------------------------------------
    -- Functions
    --------------------------------------------------------------------------
    function to_int        (slv : std_ulogic_vector) return integer;
    function slv_to_hstring(slv : std_ulogic_vector) return string;
    function index_size_f  (n : natural) return natural;
    function lfsr(seed : std_ulogic_vector(31 downto 0)) return std_ulogic_vector;

end package cpu_pkg;


--==============================================================================
-- PACKAGE BODY
--==============================================================================

package body cpu_pkg is

    --------------------------------------------------------------------------
    -- Function : to_int
    -- Purpose  : Converts a std_logic_vector to an unsigned integer.
    --------------------------------------------------------------------------
    function to_int(slv : std_ulogic_vector) return integer is
    begin
        return to_integer(unsigned(slv));
    end function;

    --------------------------------------------------------------------------
    -- Function : slv_to_hstring
    -- Purpose  : Converts a std_logic_vector to a hexadecimal string.
    --            Compatible with VHDL-2008 (replacement for to_hstring).
    --------------------------------------------------------------------------
    function slv_to_hstring(slv : std_ulogic_vector) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        constant PAD_LEN   : integer := ((slv'length + 3) / 4) * 4;
        variable padded    : std_ulogic_vector(PAD_LEN - 1 downto 0) := (others => '0');
        variable nibble    : std_ulogic_vector(3 downto 0);
        variable result    : string(1 to PAD_LEN / 4);
        variable idx       : integer;
    begin
        padded(slv'length - 1 downto 0) := slv;
        for i in result'range loop
            nibble := padded(PAD_LEN - 1 - (i-1)*4 downto PAD_LEN - i*4);
            idx    := to_integer(unsigned(nibble));
            result(i) := HEX_CHARS(idx + 1);
        end loop;
        return result;
    end function;

    
    -- Minimal required number of bits to represent <input> numbers ---------------------------
    -- -------------------------------------------------------------------------------------------

    function index_size_f(n : natural) return natural is
    begin

        for i in 0 to 31 loop
            if (2**i >= n) then
                return i;
            end if;
        end loop;
        return 32; -- fallback
    end function index_size_f;

    -- 32-bit Fibonacci LFSR with taps at registers R32, R22, R2 and R1
    -- -----------------------------------------------------------------------------------------------
    function lfsr(seed : std_ulogic_vector(31 downto 0)) return std_ulogic_vector is

        variable s : std_ulogic_vector(31 downto 0) := seed;
        variable b : std_ulogic;
    begin

        b := s(31) xor s(21) xor s(1) xor s(0);
        s := b & s(31 downto 1);

        return s;

    end function lfsr;
    
end package body cpu_pkg;





