--==============================================================================
--  Description :
--      Sign extender for immediate values (currently supports I-type only).
--      Extracts the 12-bit immediate from the instruction and performs
--      sign extension to ADDR_WIDTH bits.
--
--  Author      : Olivier
--  Created     : 10/04/2026
--  Last update : 17/04/2026
--
--  Version     : 1.8
--
--  Project     : CPU
--  Language    : VHDL
--
--  Dependencies:
--      - cpu_pkg (ADDR_WIDTH definition)
--
--  Generics:
--      None
--
--  Ports:
--      raw_src   : in  std_logic_vector(24 downto 0)
--          -- Instruction without opcode (bits [31:7])
--
--      inst_code : in  std_logic_vector(1 downto 0)
--          -- Instruction type selector:
--          -- "00" = I-type
--
--      immediate : out std_logic_vector(ADDR_WIDTH-1 downto 0)
--          -- Sign-extended immediate value
--
--  Behavior:
--      - I-type ("00"):
--          • Extract bits [25:14] from raw_src → 12-bit immediate
--          • Sign-extend to ADDR_WIDTH bits
--
--      - Other types:
--          • Output = 0
--
--  Notes:
--      - Only I-type is currently implemented
--      - Sign bit = immediate(11)
--      - Extension is combinational
--
--  License: MIT
--==============================================================================

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;


entity sign_extender is port(
    raw_src                : in std_ulogic_vector(24 downto 0); -- Instruction once opcode (6 downto 0) is removed from it
    inst_code              : in std_ulogic_vector(6 downto 0);  -- Give the type of instruction (R,I,S,U,J)
    immediate              : out std_ulogic_vector(ADDR_WIDTH-1 downto 0) 
);
end entity sign_extender;

architecture rtl of sign_extender is

begin

    proc_comb1: process(raw_src, inst_code)
    begin


        case (inst_code) is

            when "0000011" => -- I-type instruction

                immediate <= (ADDR_WIDTH-1 downto 12 => raw_src(24)) & raw_src(24 downto 13);
            
            
            when "0100011" => -- S-type instruction

                immediate <= (ADDR_WIDTH-1 downto 12 => raw_src(24)) &
                              raw_src(24 downto 18) & raw_src(4 downto 0);

            when others =>
                immediate <= (others => '0');

        end case;

    end process proc_comb1;
    

end architecture rtl;