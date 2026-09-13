--==============================================================================
--  Description :
--      Sign extender for immediate values. Supports the I, S, B, J and
--      U instruction formats defined by RV32I. Extracts the immediate
--      field from the instruction (per format) and sign-extends it to
--      ADDR_WIDTH bits.
--
--  Author      : Olivier
--  Created     : 10/04/2026
--  Last update : 02/09/2026
--
--  Version     : 1.9
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
--      inst_code : in  std_logic_vector(6 downto 0)
--          -- Instruction opcode, selects the immediate format:
--          -- "0000011" | "0010011"    = I-type (LW / ALU immediate)
--          -- "0100011"                = S-type (SW)
--          -- "1100011"                = B-type (branches)
--          -- "1101111"                = J-type (JAL)
--          -- "0110111" | "0010111"    = U-type (LUI, AUIPC)
--          -- anything else            = no immediate (output = 0)
--
--      immediate : out std_logic_vector(ADDR_WIDTH-1 downto 0)
--          -- Sign-extended immediate value
--
--  Behavior:
--      - I-type ("0000011" | "0010011"):
--          • Extract bits [25:14] from raw_src → 12-bit immediate
--          • Sign-extend to ADDR_WIDTH bits
--
--      - S-type ("0100011"):
--          • Extract bits [24:18] and [4:0] from raw_src → 12-bit immediate
--          • Sign-extend to ADDR_WIDTH bits
--
--      - B-type ("1100011"):
--          • Reassemble the 13-bit branch offset (bit 0 forced to 0)
--          • Sign-extend to ADDR_WIDTH bits
--
--      - J-type ("1101111"):
--          • Reassemble the 21-bit jump offset (bit 0 forced to 0)
--          • Sign-extend to ADDR_WIDTH bits
--
--      - U-type ("0110111" | "0010111"):
--          • Place bits [24:5] of raw_src in immediate[31:12]
--          • immediate[11:0] = 0 (no sign extension needed)
--
--      - Other types:
--          • Output = 0
--
--  Notes:
--      - Sign bit = raw_src(24) (instruction bit 31) for I/S/B/J types
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

        immediate <= (others => '0');

        case (inst_code) is

            when OPCODE_LOAD | OPCODE_ITYPE | OPCODE_JALR => -- LOAD / I-type ALU instruction

                immediate(ADDR_WIDTH-1 downto 12) <=
                    (others => raw_src(24));

                immediate(11 downto 0) <=
                    raw_src(24 downto 13);


            when OPCODE_STORE => -- S-type instruction

                immediate(ADDR_WIDTH-1 downto 12) <=
                    (others => raw_src(24));

                immediate(11 downto 5) <=
                    raw_src(24 downto 18);

                immediate(4 downto 0) <=
                    raw_src(4 downto 0);

            when OPCODE_BRANCH => -- B-type instruction

                immediate <= (others => raw_src(24));
                immediate(12)          <= raw_src(24);
                immediate(11)          <= raw_src(0);
                immediate(10 downto 5) <= raw_src(23 downto 18);
                immediate(4 downto 1)  <= raw_src(4 downto 1);
                immediate(0)           <= '0';

            when OPCODE_JAL => -- J-type 

                immediate(31 downto 20) <= (others => raw_src(24));
                immediate(19 downto 12) <= raw_src(12 downto 5);
                immediate(11)           <= raw_src(13);
                immediate(10 downto 1)  <= raw_src(23 downto 14);
                immediate(0)           <= '0';

            when OPCODE_LUI | OPCODE_AUIPC => -- U-type 

                immediate(31 downto 12) <= raw_src(24 downto 5);
                immediate(11 downto 0)  <= (others => '0');

            when others =>
                immediate <= (others => '0');

        end case;

    end process proc_comb1;
    

end architecture rtl;
