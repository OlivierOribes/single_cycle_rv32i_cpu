--==============================================================================
--  Description :
--      Testbench used to validate mux through simulation
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
--  Generic: 
--          DATA_WIDTH : integer (default 32)
--
--  Ports:
--          data_i1 : in std_ulogic_vector(DATA_WIDTH - 1 downto 0)
--          data_i2 : in std_ulogic_vector(DATA_WIDTH - 1 downto 0)
--          op      : in std_ulogic
--          data_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
--      
--  
--  License: MIT
--==============================================================================


library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cpu_pkg.all;

entity tb_mux is
end entity tb_mux;


architecture sim of tb_mux is

    constant DATA_WIDTH : integer := 32;
    constant N          : integer := 500;
    constant seed1       : std_ulogic_vector := x"A5C3F19B";
    constant seed2       : std_ulogic_vector := x"DEADBEEF";
    signal data_i1      : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal data_i2      : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal op           : std_ulogic := '0';
    signal data_o       : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

begin

    -- ------------------------------------------------------------------
    -- DUT
    -- ------------------------------------------------------------------

    DUT : entity work.mux
        port map(
                data_i1     => data_i1,
                data_i2     => data_i2,
                op          => op,
                data_o      => data_o
        );



    -- Simulation

    STIM: process

        variable error1       : natural := 0;
        variable error2       : natural := 0;
        variable error3       : natural := 0;
        variable error4       : natural := 0;
        variable total_err    : natural := 0;
        variable randvec1     : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := seed1;
        variable randvec2     : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := seed2;
        variable rnd          : std_ulogic_vector(2 downto 0) := (others => '0');
        variable undefinedvec : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => 'X');
    begin


    -- ================================================================
    -- Test 1 : data_o = data_i1 when op = 0
    -- ================================================================

    for i in 0 to N loop

        randvec1 := lfsr(randvec1);
        randvec2 := lfsr(randvec2);
        op <= '0';
        data_i1 <= randvec1;
        data_i2 <= randvec2;

        wait for 1 ns;

        if (data_o /= data_i1) then

            report "Error test 1: data_o shoud be equal to " & slv_to_hstring(data_i1) & LF &
                   "but got : " & slv_to_hstring(data_o) & LF
                   severity error;
                
            error1 := error1 + 1;

        end if;

    end loop;

    -- ================================================================
    -- Test 2 : data_o = data_i2 when op = 1
    -- ================================================================

    for i in 0 to N loop

        randvec1 := lfsr(randvec1);
        randvec2 := lfsr(randvec2);
        op <= '1';
        data_i1 <= randvec1;
        data_i2 <= randvec2;

        wait for 1 ns;

        if (data_o /= data_i2) then

            report "Error test 2: data_o shoud be equal to " & slv_to_hstring(data_i2) & LF &
                   "but got : " & slv_to_hstring(data_o) & LF
                   severity error;
                
            error2 := error2 + 1;
            
        end if;

    end loop;
    
    -- ================================================================
    -- Test 3 : data_o = (others => 'X') when op is undefined
    -- ================================================================

    for i in 0 to N loop

        randvec1 := lfsr(randvec1);
        randvec2 := lfsr(randvec2);
        op <= 'X';
        data_i1 <= randvec1;
        data_i2 <= randvec2;

        wait for 1 ns;

        if (data_o /= undefinedvec) then

            report "Error test 3: data_o shoud be equal to " & slv_to_hstring(undefinedvec) & LF &
                   "but got : " & slv_to_hstring(data_o) & LF
                   severity error;
                
            error3 := error3 + 1;
            
        end if;

    end loop;

    
    -- ================================================================
    -- Test 4 : expected data_o value when op value is modified
    -- ================================================================

    for i in 0 to N loop

        randvec1 := lfsr(randvec1);
        randvec2 := lfsr(randvec2);
        rnd := randvec1(2 downto 0);
        data_i1 <= randvec1;
        data_i2 <= randvec2;

        case (rnd) is 

            when "000" => 
                op <= '0';

            when "001" => 
                op <= '1';
            
            when "010" => 
                op <= 'Z';

            when "100" => 
                op <= 'W';

            when "110" => 
                op <= 'L';

            when "111" => 
                op <= 'U';

            when "101" => 
                op <= 'H';

            when others => 
                op <= 'X';

        end case;

        wait for 1 ns;

        case (op) is

            when '0' =>

                if (data_o /= data_i1) then

                    report "Error test 4: data_o shoud be equal to " & slv_to_hstring(data_i1) & LF &
                        "but got : " & slv_to_hstring(data_o) & LF
                        severity error;
                        
                    error4 := error4 + 1;

                end if;
            
            when '1' =>

                if (data_o /= data_i2) then

                    report "Error test 4: data_o shoud be equal to " & slv_to_hstring(data_i2) & LF &
                        "but got : " & slv_to_hstring(data_o) & LF
                        severity error;
                        
                    error4 := error4 + 1;
                
                end if;
            
            when others =>

                if (data_o /= undefinedvec) then

                    report "Error test 4: data_o shoud be equal to " & slv_to_hstring(undefinedvec) & LF &
                        "but got : " & slv_to_hstring(data_o) & LF
                        severity error;
                
                error4 := error4 + 1;
            
                end if;

        end case;

    end loop;


    -- ================================================================
    -- Fin de simulation
    -- ================================================================
    
    total_err := error1 + error2 + error3 + error4;

    if (total_err = 0) then
            report "ALL TESTS PASSED" severity note;
    else
        report "SIMULATION FINISHED WITH " &
                integer'image(total_err) & " ERROR(S)"
                severity failure;
    end if;


    report "End of simulation" severity note;
    wait;

    end process STIM;

end architecture sim;