--==============================================================================
--  Description :
--      Sign extender testbench used to validate sign_extender module through simulation.
--
--  Author      : Olivier
--  Created     : 17/04/2026
--  Last update : 17/04/2026
--
--  Version     : 1.0
--
--  Project     : CPU
--  Language    : VHDL
--
--  Dependencies:
--      - cpu_pkg
--
--  Generics:
--      None
--
--  Ports:
--      raw_src   : in  std_ulogic_vector(24 downto 0)
--          -- Instruction without opcode (bits [31:7])
--
--      inst_code : in  std_ulogic_vector(6 downto 0)
--          -- Instruction type selector:
--          -- "0010011" = I-type
--
--      immediate : out std_ulogic_vector(31 downto 0)
--          -- Sign-extended immediate value
--
--  Behavior:
--      - I-type ("0010011"):
--          • Extract bits [24:13] from raw_src → 12-bit immediate
--          • Sign-extend to 32 bits
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
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cpu_pkg.all;

entity tb_sign_extender is
end entity tb_sign_extender;

architecture sim of tb_sign_extender is 
    
    -- ------------------------------------------------------------------
    -- Constants / signals
    -- ------------------------------------------------------------------

    constant N       : integer := 1000;
    constant seed    : std_ulogic_vector(31 downto 0) := x"FA04_BCDE";
    signal raw_src   : std_ulogic_vector(24 downto 0) := (others => '0'); -- input raw_src
    signal inst_code : std_ulogic_vector(6 downto 0)  := (others => '0'); -- input inst_code
    signal immediate : std_ulogic_vector(31 downto 0) := (others => '0'); 
    
begin

     -- ------------------------------------------------------------------
    -- DUT
    -- ------------------------------------------------------------------

    DUT : entity work.sign_extender
        port map(
                raw_src     => raw_src,
                inst_code   => inst_code,
                immediate   => immediate
        );
    
    -- ------------------------------------------------------------------
    -- Stimulus
    -- ------------------------------------------------------------------
    STIM : process

        variable error1         : integer := 0;
        variable error2         : integer := 0;
        variable total_error    : integer := 0;
        variable randvec        : std_ulogic_vector(31 downto 0) := seed;
        variable I_instruction  : std_ulogic_vector(6 downto 0)  := "0010011";
        variable imm            : std_ulogic_vector(31 downto 0) := (others => '0');
        
    begin

        -- -------------------------------------------------------------------
        -- Test 1 : correct output when inst_code matches with case conditions
        -- -------------------------------------------------------------------

        for i in 0 to N loop

            randvec := lfsr(randvec);
            imm := (31 downto 12 => randvec(24)) & randvec(24 downto 13);
            raw_src <= randvec(24 downto 0);
            inst_code <= I_instruction;

            wait for 1 ns;

            if (immediate /= imm) then

                report "immediate output should be equal to " & slv_to_hstring(imm) & LF &
                       "but got : " & slv_to_hstring(immediate) & LF
                       severity error;

                error1 := error1 + 1;

            end if;

        end loop;

        -- -------------------------------------------------------------------
        -- Test 2 : output equal to 0 when inst_code is unknown 
        -- -------------------------------------------------------------------

        for i in 0 to N loop

            randvec := lfsr(randvec);
            imm := (others => '0');
            raw_src <= randvec(24 downto 0);

            while (randvec(6 downto 0) = I_instruction) loop

                randvec := lfsr(randvec);

            end loop;

            inst_code <= randvec(6 downto 0);

            wait for 1 ns;

            if (immediate /= imm) then

                report "immediate output should be equal to " & slv_to_hstring(imm) & LF &
                       "but got : " & slv_to_hstring(immediate) & LF
                       severity error;

                error2 := error2 + 1;

            end if;

        end loop;

        -- ================================================================
        -- Fin de simulation
        -- ================================================================
        
        total_error := error1 + error2;

        if (total_error = 0) then

            report "ALL TEST PASSED!" & LF 
            severity note;
        
        else
            report "SIMULATION FINISHED WITH " &
                    integer'image(total_error) & " ERROR(S)"
                    severity failure;
        end if;


        report "End of simulation" severity note;
        wait;

    end process STIM;

end architecture sim;