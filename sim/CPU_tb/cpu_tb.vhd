--==============================================================================
--  Module      : CPU testbench
--  File        : cpu_tb.vhd
--  Description : Top-level single-cycle RISC-V CPU testbench. it checks that lw instruction 
--                are working properly.
--
--
--  Author      : Olivier Oribes
--  Created     : 24/07/2026
--  Last update : 24/07/2026
--
--  Version     : 1.0
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--
--  License     : MIT (see LICENSE file)
--==============================================================================

library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;


entity cpu_tb is
end entity;


architecture sim of cpu_tb is

    constant ZERO32 : std_ulogic_vector(31 downto 0):= (others => '0');

    signal clk   : std_ulogic := '0';
    signal rst_n : std_ulogic := '1';

    -- Debut signals
    signal rs1_o       :  std_ulogic_vector(4 downto 0);
    signal rs1_data_o  :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rd_o        :  std_ulogic_vector(4 downto 0);
    signal imm         :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal alu_res_o   :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rf_wd       :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal pc_reg      :  std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal instruction :  std_ulogic_vector(DATA_WIDTH-1 downto 0);

begin

    -- ------------------------------------------------------------------
    -- Clock generation : 100 MHz
    -- ------------------------------------------------------------------
    clk <= not clk after 5 ns;

    -- ------------------------------------------------------------------
    -- DUT
    -- ------------------------------------------------------------------
    DUT : entity work.cpu
        port map(
            clk   => clk,
            rst_n => rst_n,

            rs1_o       => rs1_o,
            imm         => imm,
            rd_o        => rd_o,
            alu_res_o   => alu_res_o,
            rf_wd       => rf_wd,
            pc_reg      => pc_reg,
            instruction => instruction,
            rs1_data_o  => rs1_data_o
        );

    -- ------------------------------------------------------------------
    -- Stimulus
    -- ------------------------------------------------------------------
    STIM : process

        constant instruction1 : std_ulogic_vector(31 downto 0)  := x"00022283"; --  lw x5, 0(x4)
        constant instruction2 : std_ulogic_vector(31 downto 0)  := x"00422303"; --  lw x6, 4(x4)
        constant instruction3 : std_ulogic_vector(31 downto 0)  := x"00822383"; --  lw x7, 8(x4)
        constant instruction4 : std_ulogic_vector(31 downto 0)  := x"00C22403"; --  lw x8, 12(x4)

        variable error_count  : integer := 0;
        variable alu_resultat : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
        variable immediate_I  : std_ulogic_vector(DATA_WIDTH - 1  downto 0):= (others => '0');
        variable pc_rg        : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
        variable rs1_i        : std_ulogic_vector(4 downto 0):= (others => '0');
        variable rs2_i        : std_ulogic_vector(4 downto 0):= (others => '0');
        variable rd_i         : std_ulogic_vector(4 downto 0):= (others => '0');
        variable rf_wdata     : std_ulogic_vector(DATA_WIDTH - 1 downto 0):= (others => '0');

        
        procedure lw_test(  constant pc_register  : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                            constant instr        : in std_ulogic_vector(31 downto 0);
                            constant imme         : in std_ulogic_vector(11 downto 0);
                            constant alu_o        : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                            constant rs1_ad       : in std_ulogic_vector(4 downto 0);
                            constant desti_reg    : in std_ulogic_vector(4 downto 0);
                            constant wb_data      : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                            variable err          : inout integer) is  
        begin

            if (pc_reg /= pc_register) then

            report "pc_reg should be equal to " & slv_to_hstring(pc_register) &
            " , but got " & slv_to_hstring(pc_reg)
            severity error;

            err := err + 1;

            end if;

            if (instruction /= instr) then

                report "instruction should be equal to " & slv_to_hstring(instr) &
                " , but got " & slv_to_hstring(instruction)
                severity error;

                err := err + 1;

            end if;

            if (imm(11 downto 0) /= imme) then

                report "immediate should be equal to " & slv_to_hstring(imme) &
                       ", but got " & slv_to_hstring(imm(11 downto 0))
                severity error;

                err := err + 1;

            end if;

            if (alu_res_o /= alu_o) then

                report "alu_res should be equal to " & slv_to_hstring(alu_o) &
                ", but got " & slv_to_hstring(alu_res_o)
                severity error;

                err := err + 1;

            end if;


            if (rs1_o /= rs1_ad) then

                report "rs1 should be equal to " & slv_to_hstring(rs1_ad) & ", but got " & slv_to_hstring(rs1_o)
                severity error;

                err := err + 1;

            end if;



            if (rd_o /= desti_reg) then

                report "rd should be equal to " & slv_to_hstring(desti_reg) & ", but got " & slv_to_hstring(rd_o)
                severity error;

                err := err + 1;

            end if;


            if (rf_wd /= wb_data) then

                report "rf_wdata should be equal to " & slv_to_hstring(wb_data) & ", but got " & slv_to_hstring(rf_wd)
                severity error;

                err := err + 1;

            end if;


            if (err = 0) then

                report "Test passed!" severity note;
            else 

                report "Test finished with " & integer'image(err) &
                    " error(s)" 
                    severity note;
            end if;

        end procedure;

    begin


        -- ----------------------------------------------------------------
        -- Init
        -- ----------------------------------------------------------------

        rst_n <= '0';

        wait for 1 ns;

        rst_n <= '1';

        wait for 1 ns;


        -- ================================================================
        -- LOAD WORD INSTRUCTION TEST
        -- ================================================================

            -- ----------------------------------------------------------------
            -- Test 1
            -- ----------------------------------------------------------------

            pc_rg        := ZERO32;
            immediate_I  := (others => '0');
            immediate_I(11 downto 0) := instruction1(31 downto 20);
            rs1_i        := instruction1(19 downto 15);
            rd_i         := instruction1(11 downto 7);
            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate_I));
            rf_wdata     := x"12345678";
            error_count  := 0;

            lw_test(pc_reg, instruction1, immediate_I(11 downto 0), alu_resultat, rs1_i, rd_i, rf_wdata, error_count);
    
            -- ----------------------------------------------------------------
            -- Test 2
            -- ----------------------------------------------------------------
            
            wait until rising_edge(clk);
            wait for 1 ns;

            pc_rg        := std_ulogic_vector(unsigned(pc_rg ) + 4);
            immediate_I  := (others => '0');
            immediate_I(11 downto 0) := instruction2(31 downto 20);
            rs1_i        := instruction2(19 downto 15);
            rd_i         := instruction2(11 downto 7);
            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate_I));
            rf_wdata     := x"DEADBEEF";
            error_count  := 0;

            lw_test(pc_reg, instruction2, immediate_I(11 downto 0), alu_resultat, rs1_i, rd_i, rf_wdata, error_count);

            -- ----------------------------------------------------------------
            -- Test 3
            -- ----------------------------------------------------------------
            
            wait until rising_edge(clk);
            wait for 1 ns;

            pc_rg        := std_ulogic_vector(unsigned(pc_rg ) + 4);
            immediate_I  := (others => '0');
            immediate_I(11 downto 0) := instruction3(31 downto 20);
            rs1_i        := instruction3(19 downto 15);
            rd_i         := instruction3(11 downto 7);
            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate_I));
            rf_wdata     := x"CAFEBABE";
            error_count  := 0;

            lw_test(pc_reg, instruction3, immediate_I(11 downto 0), alu_resultat, rs1_i, rd_i, rf_wdata, error_count);

            -- ----------------------------------------------------------------
            -- Test 4
            -- ----------------------------------------------------------------
            
            wait until rising_edge(clk);
            wait for 1 ns;

            pc_rg        := std_ulogic_vector(unsigned(pc_rg ) + 4);
            immediate_I  := (others => '0');
            immediate_I(11 downto 0) := instruction4(31 downto 20);
            rs1_i        := instruction4(19 downto 15);
            rd_i         := instruction4(11 downto 7);
            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate_I));
            rf_wdata     := x"0BADF00D";
            error_count  := 0;

            lw_test(pc_reg, instruction4, immediate_I(11 downto 0), alu_resultat, rs1_i, rd_i, rf_wdata, error_count);


            if (error_count = 0) then

                report "ALL TEST PASSED!" severity note;

            end if;

            
            assert false
                report "End of simulation"
                severity failure;

        
        -- ================================================================
        -- SAVE WORD INSTRUCTION TEST
        -- ================================================================




    end process STIM;


end architecture sim;