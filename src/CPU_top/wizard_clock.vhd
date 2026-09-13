--==============================================================================
--  Module      : Wizard Clock (Clock Divider)
--  File        : wizard_clock.vhd
--  Description : Divides clk_i by (filter_ratio + 1) using a counter to
--                generate clk_o.
--
--  Author      : Olivier Oribes
--  Created     : 2026-09-13
--  Last update : 2026-09-13
--
--  Version     : 1.0
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--  Dependencies:
--      - work.cpu_pkg
--
--  Ports:
--      clk_i : in  std_ulogic -- clock input
--      rst_n : in  std_ulogic -- asynchronous active-low reset
--      clk_o : out std_ulogic -- divided clock output
--==============================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;


entity wizard_clock is port
(
    clk_i : in  std_ulogic; -- clock input
    rst_n : in  std_ulogic;
    clk_o : out std_ulogic -- clock output
);
end entity wizard_clock;

architecture rlt of wizard_clock is

    signal filter_ratio : integer    := 10;
    signal clk          : std_ulogic := '0';

begin

    proc_div : process(clk_i, rst_n)
        variable count  : integer := 0;
    begin

        if rst_n = '0' then

            count := 0;
            clk   <= '0';

        elsif rising_edge(clk_i) then
            if count = filter_ratio then

                count := 0;
                clk <= not clk;

            else 
                count := count + 1;
            end if;

        end if;

    end process proc_div;

    clk_o <= clk;


end architecture rlt;