--==============================================================================
--  Module      : Program Counter Testbench
--  File        : tb_program_counter.vhd
--  Description : VHDL testbench for the program_counter module.
--                Verifies the following behaviors:
--                  - asynchronous reset
--                  - normal incrementation (PC + 4)
--                  - jump loading when load = '1'
--
--  Author      : Olivier Oribes
--  Created     : 2026-03-09
--  Last update : 2026-03-27
--
--  Version     : 1.1
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--  Dependencies:
--      - program_counter.vhd
--
--  Generics:
--      - WIDTH : program counter width in bits
--
--  Ports:
--      None (testbench entity has no ports)
--
--  Test sequence:
--      1. Reset assertion
--      2. Reset release
--      3. Sequential incrementation (PC + 4)
--      4. Jump loading
--      5. Reset re-assertion
--
--  Notes:
--      - This testbench is intended for simulation only.
--      - Clock period: 10 ns
--      - to_hstring replaced by slv_to_hstring for broader VHDL compatibility
--
--  License     : MIT (see LICENSE file)
--==============================================================================

-- **********************************************************************
-- Libraries
-- **********************************************************************
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- **********************************************************************
--  Testbench entity declaration
-- **********************************************************************
entity tb_program_counter is
end entity;

architecture SIM of tb_program_counter is

    -- ------------------------------------------------------------------
    -- Function : slv_to_hstring
    -- Purpose  : Converts a std_logic_vector to a hexadecimal string.
    --            Replacement for to_hstring (VHDL-2008 only).
    -- ------------------------------------------------------------------
    function slv_to_hstring(slv : std_logic_vector) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        -- Pad to a multiple of 4 bits
        constant PAD_LEN   : integer := ((slv'length + 3) / 4) * 4;
        variable padded    : std_logic_vector(PAD_LEN - 1 downto 0) := (others => '0');
        variable nibble    : std_logic_vector(3 downto 0);
        variable result    : string(1 to PAD_LEN / 4);
        variable idx       : integer;
    begin
        padded(slv'length - 1 downto 0) := slv;
        for i in result'range loop
            nibble := padded(PAD_LEN - 1 - (i-1)*4 downto PAD_LEN - i*4);
            idx := to_integer(unsigned(nibble));
            result(i) := HEX_CHARS(idx + 1);
        end loop;
        return result;
    end function;



    constant WIDTH        : integer  := 32;
    constant C_CLK_PERIOD : time     := 10 ns;
    constant ZERO : std_logic_vector(WIDTH-1 downto 0) := (others => '0');

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal load     : std_logic := '0';
    signal pc_in    : std_logic_vector(WIDTH-1 downto 0);
    signal pc_out   : std_logic_vector(WIDTH-1 downto 0);
    signal pc_reg   : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    

begin

    -- Instance of program_counter for simulation
    DUT : entity work.program_counter
        port map(clk    => clk,
                 rst_n  => rst_n,
                 load   => load,
                 pc_in  => pc_in,
                 pc_out => pc_out);

    -- Clock generation
    clk <= not clk after C_CLK_PERIOD/2;

    -- Simulation

    STIM: process
        variable pc_ref : std_logic_vector(WIDTH-1 downto 0);

    begin
        
        
        -- Initialisation
        rst_n <= '0';
        load  <= '0';
        pc_in <= (others => '0');
        pc_ref := (others => '0');

        wait for 20 ns;


        assert rst_n = '0'
            report "ERROR: reset should be equal to '0' but got " & std_logic'image(rst_n)
            severity error;
        load  <= '0';
        pc_in <= (others => '0');

        wait until rising_edge(clk);

        rst_n <= '1';

        wait until rising_edge(clk);
        
        assert rst_n = '1'
            report "ERROR: reset should be equal to '1' but got " & std_logic'image(rst_n)
            severity error;


        -- =========================
        -- Test incrementation
        -- =========================

        for i in 0 to 20 loop

            assert pc_out = pc_ref
                report "ERROR: pc_out should be equal to 0x" &
                    slv_to_hstring(pc_ref) &
                    " but got 0x" &
                    slv_to_hstring(pc_out)
                severity error;
            
            report "pc_out = 0x" & slv_to_hstring(pc_out) &
                 ", pc_reg = 0x" & slv_to_hstring(pc_ref)
            severity note;
            
            wait until rising_edge(clk);

            -- 4-byte incrementation for 32-bit RISC-V architecture
            pc_ref := std_logic_vector(unsigned(pc_ref) + 4);

        end loop;

        wait for 20 ns;


        -- =========================
        -- Test jump
        -- =========================
        pc_in <= std_logic_vector(to_unsigned(520, WIDTH));
        load  <= '1';

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        load <= '0';
        
        pc_ref := pc_in;

        assert pc_out = pc_ref
            report "ERROR: pc_out should be equal to 0x" &
                slv_to_hstring(pc_ref) &
                " but got 0x" &
                slv_to_hstring(pc_ref)
            severity error;

        wait until rising_edge(clk);
        wait until rising_edge(clk);


        -- =========================
        -- Test reset
        -- =========================
        rst_n <= '0';
        pc_ref := (others => '0');

        wait until rising_edge(clk);

        assert pc_out = pc_ref
            report "ERROR: pc_out should be equal to 0x" &
                slv_to_hstring(pc_ref) &
                " but got 0x" &
                slv_to_hstring(pc_out)
            severity error;

        wait until rising_edge(clk);

    
    report "End of simulation."
    severity note;
    
    wait;

    end process;    

end architecture SIM;
