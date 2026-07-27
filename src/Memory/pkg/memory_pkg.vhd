--==============================================================================
--  Package:       memory_pkg
--  Project:       memory
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package memory_pkg is

    constant DATA_WIDTH : integer := 32;
    constant ADDR_WIDTH : integer := 32;

    ----------------------------------------------------------------------------
    -- Functions
    ----------------------------------------------------------------------------

    function to_int(slv : std_logic_vector) return integer;

    function slv_to_hstring(slv : std_logic_vector) return string;

end package memory_pkg;

--==============================================================================
-- PACKAGE BODY
--==============================================================================

package body memory_pkg is

    ----------------------------------------------------------------------------
    -- Function : to_int
    ----------------------------------------------------------------------------
    function to_int(slv : std_logic_vector) return integer is
    begin
        return to_integer(unsigned(slv));
    end function;

    ----------------------------------------------------------------------------
    -- Function : slv_to_hstring
    ----------------------------------------------------------------------------
    function slv_to_hstring(slv : std_logic_vector) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        constant PAD_LEN   : integer := ((slv'length + 3) / 4) * 4;

        variable padded : std_logic_vector(PAD_LEN - 1 downto 0) := (others => '0');
        variable nibble : std_logic_vector(3 downto 0);
        variable result : string(1 to PAD_LEN / 4);
        variable idx    : integer;
    begin
        padded(slv'length - 1 downto 0) := slv;

        for i in result'range loop
            nibble := padded(PAD_LEN - 1 - (i-1)*4 downto PAD_LEN - i*4);
            idx := to_integer(unsigned(nibble));
            result(i) := HEX_CHARS(idx + 1);
        end loop;

        return result;
    end function;

end package body memory_pkg;
