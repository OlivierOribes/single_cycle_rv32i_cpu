--==============================================================================
--  Module      : CPU testbench
--  File        : cpu_tb.vhd
--  Description : Top-level single-cycle RISC-V CPU testbench. it checks that lw instruction 
--                are working properly.
--
--
--  Author      : Olivier Oribes
--  Created     : 24/07/2026
--  Last update : 02/09/2026
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
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_textio.all;
use work.cpu_pkg.all;

library std;
use std.textio.all;


entity cpu_tb is
end entity;


architecture sim of cpu_tb is

    constant ZERO32 : std_ulogic_vector(31 downto 0):= (others => '0');

    signal clk   : std_ulogic := '0';
    signal rst_n : std_ulogic := '1';

    -- Debut signals
    signal rs1_o       :  std_ulogic_vector(4 downto 0);
    signal rs1_data_o  :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rs2_o       :  std_ulogic_vector(4 downto 0);
    signal rs2_data_o  :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rd_o        :  std_ulogic_vector(4 downto 0);
    signal imm         :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal alu_res_o   :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal alu_status  :  std_ulogic_vector(5 downto 0); -- (C, Z, N, V)
    signal rf_wd       :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal pc_reg      :  std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal pc_src      :  pc_src_t;
    signal instruction :  std_ulogic_vector(DATA_WIDTH-1 downto 0);

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

    -- Memory initialisation from an external file
    impure function init_memory(
        file_name : string
    ) return imem_ram_t is

        file memory_file : text open read_mode is file_name;

        variable current_line : line;
        variable memory       : imem_ram_t := (others => (others => '0'));
        variable instruction  : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        variable index        : natural := 0;
    begin

        while not endfile(memory_file) loop

            exit when index >= INST_DEPTH;

            readline(memory_file, current_line);
            hread(current_line, instruction);

            memory(index) := std_ulogic_vector(instruction);

            index := index + 1;
             
        end loop;

        return memory;

    end function init_memory;

    -- Modelsim internal signals view
    alias regfile_view is
        << signal .cpu_tb.DUT.register_file_inst.regfile :
            reg_array >>;
    
    alias dmem_view is
        << signal .cpu_tb.DUT.data_memory_inst.data_mem :
            dmem_ram_t >>;

    alias imem_view is
        << signal .cpu_tb.DUT.instruction_memory_inst.mem :
            imem_ram_t >>;

    signal dmem_copy : dmem_ram_t := init_memory("dmem_init.hex");
    signal imem_copy : imem_ram_t := init_memory("program.hex");

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

            rs1_o        => rs1_o,
            rs2_o        => rs2_o,
            imm          => imm,
            rd_o         => rd_o,
            alu_res_o    => alu_res_o,
            alu_status_o => alu_status,
            rf_wd        => rf_wd,
            pc_out       => pc_reg,
            PC_source    => pc_src,
            instruction  => instruction,
            rs1_data_o   => rs1_data_o,
            rs2_data_o   => rs2_data_o
        );

    -- ------------------------------------------------------------------
    -- Stimulus
    -- ------------------------------------------------------------------
    STIM : process

        constant BYTES_PER_WORD : integer := 4;

        variable error_count  : integer := 0;
        variable alu_resultat : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
        variable immediate  : std_ulogic_vector(DATA_WIDTH - 1  downto 0):= (others => '0');
        variable pc_rg        : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
        variable rs1_i        : std_ulogic_vector(4 downto 0):= (others => '0');
        variable rs2_i        : std_ulogic_vector(4 downto 0):= (others => '0');
        variable rs2_d_out    : std_ulogic_vector(DATA_WIDTH - 1 downto 0):= (others => '0');
        variable rd_i         : std_ulogic_vector(4 downto 0):= (others => '0');
        variable rf_wdata     : std_ulogic_vector(DATA_WIDTH - 1 downto 0):= (others => '0');
        variable mem_wdata    : std_ulogic_vector(DATA_WIDTH - 1 downto 0):= (others => '0');
        variable instruct     : std_ulogic_vector(DATA_WIDTH -1 downto 0) := (others => '0');
        variable reg_index    : integer := 0;
        variable dmem_index   : integer := 0;
        variable imem_index   : integer := 0;
        variable sign         : std_ulogic;
        
        procedure lw_test(  constant test_nbr     : in integer;
                            constant pc_register  : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                            constant instr        : in std_ulogic_vector(31 downto 0);
                            constant imme         : in std_ulogic_vector(11 downto 0);
                            constant alu_o        : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                            constant rs1_ad       : in std_ulogic_vector(4 downto 0);
                            constant desti_reg    : in std_ulogic_vector(4 downto 0);
                            constant wb_data      : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                            variable err          : inout integer) is  
        begin

            if (pc_reg /= pc_register) then

            report "LW test #" & integer'image(test_nbr) & LF & 
                   "Expected pc_reg = " & slv_to_hstring(pc_register) & LF &
                   "Observed pc_reg = " & slv_to_hstring(pc_reg) & LF
            severity error;

            err := err + 1;

            end if;

            if (instruction /= instr) then

                report "LW test #" & integer'image(test_nbr) & LF & 
                       "Expected instruction = " & slv_to_hstring(instr) & LF &
                       "Observed instruction = " & slv_to_hstring(instruction) & LF
                severity error;

                err := err + 1;

            end if;

            if (imm(11 downto 0) /= imme) then

                report "LW test #" & integer'image(test_nbr) & LF & 
                       "Expected immediate = " & slv_to_hstring(imme) & LF &
                       "Observed immediate = " & slv_to_hstring(imm(11 downto 0)) & LF
                severity error;
   
                err := err + 1;

            end if;

            if (alu_res_o /= alu_o) then

                report "LW test #" & integer'image(test_nbr) & LF & 
                       "Expected alu_res = " & slv_to_hstring(alu_o) & LF &
                       "Observed alu_res = " & slv_to_hstring(alu_res_o) & LF
                severity error;

                err := err + 1;

            end if;


            if (rs1_o /= rs1_ad) then

                report "LW test #" & integer'image(test_nbr) & LF & 
                       "Expected rs1 = " & slv_to_hstring(rs1_ad) & LF &
                       "Observed rs1 = " & slv_to_hstring(rs1_o) & LF
                severity error;

                err := err + 1;

            end if;



            if (rd_o /= desti_reg) then

                report "LW test #" & integer'image(test_nbr) & LF & 
                       "Expected rd = " & slv_to_hstring(desti_reg) & LF &
                       "Observed rd = " & slv_to_hstring(rd_o) & LF
                severity error;

                err := err + 1;

            end if;


            if (rf_wd /= wb_data) then

                report "LW test #" & integer'image(test_nbr) & LF & 
                       "Expected rf_wdata = " & slv_to_hstring(wb_data) & LF &
                       "Observed rf_wdata = " & slv_to_hstring(rf_wd) & LF
                severity error;

                err := err + 1;

            end if;

            if (err = 0) then

                report "Test #" & integer'image(test_nbr) &" passed!" severity note;
            else 

                report "Test #" & integer'image(test_nbr) & " finished with " & integer'image(err) &
                    " error(s)" 
                    severity error;
            end if;

        end procedure;

        -- ============================================================================================
        procedure sw_test(  constant test_nbr     : in integer;
                            constant pc_register  : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                            constant instr        : in std_ulogic_vector(31 downto 0);
                            constant imme         : in std_ulogic_vector(11 downto 0);
                            constant alu_o        : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                            constant rs1_ad       : in std_ulogic_vector(4 downto 0);
                            constant rs2_ad       : in std_ulogic_vector(4 downto 0);
                            variable err          : inout integer) is  
        begin

            if (pc_reg /= pc_register) then

            report "LW test #" & integer'image(test_nbr) & LF & 
                   "Expected pc_reg = " & slv_to_hstring(pc_register) & LF &
                   "Observed pc_reg = " & slv_to_hstring(pc_reg) & LF
            severity error;

            err := err + 1;

            end if;

            if (instruction /= instr) then

                report "SW test #" & integer'image(test_nbr) & LF & 
                       "Expected instruction = " & slv_to_hstring(instr) & LF &
                       "Observed instruction = " & slv_to_hstring(instruction) & LF
                severity error;

                err := err + 1;

            end if;

            if (imm(11 downto 0) /= imme) then

                report "SW test #" & integer'image(test_nbr) & LF & 
                       "Expected immediate = " & slv_to_hstring(imme) & LF &
                       "Observed immediate = " & slv_to_hstring(imm(11 downto 0)) & LF
                severity error;
   
                err := err + 1;

            end if;

            if (alu_res_o /= alu_o) then

                report "SW test #" & integer'image(test_nbr) & LF & 
                       "Expected alu_res = " & slv_to_hstring(alu_o) & LF &
                       "Observed alu_res = " & slv_to_hstring(alu_res_o) & LF
                severity error;

                err := err + 1;

            end if;


            if (rs1_o /= rs1_ad) then

                report "SW test #" & integer'image(test_nbr) & LF & 
                       "Expected rs1 = " & slv_to_hstring(rs1_ad) & LF &
                       "Observed rs1 = " & slv_to_hstring(rs1_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (rs2_o /= rs2_ad) then

                report "SW test #" & integer'image(test_nbr) & LF & 
                       "Expected rs1 = " & slv_to_hstring(rs2_ad) & LF &
                       "Observed rs1 = " & slv_to_hstring(rs2_o) & LF
                severity error;

                err := err + 1;

            end if;
    
            if (err = 0) then

                report "Test #" & integer'image(test_nbr) &" passed!" severity note;
            else 

                report "Test #" & integer'image(test_nbr) & " finished with " & integer'image(err) &
                    " error(s)" 
                    severity error;
            end if;

        end procedure;
            

        -- ============================================================================================
        procedure branch_test(  constant test_nbr     : in integer;
                                constant pc_register  : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                                constant instr        : in std_ulogic_vector(31 downto 0);
                                constant imme         : in std_ulogic_vector(12 downto 0);
                                constant alu_o        : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                                constant rs1_ad       : in std_ulogic_vector(4 downto 0);
                                constant rs2_ad       : in std_ulogic_vector(4 downto 0);
                                constant funct3       : in std_ulogic_vector(2 downto 0);
                                variable err          : inout integer) is  
        begin

            if (pc_reg /= pc_register) then

            report "BRANCH test #" & integer'image(test_nbr) & LF & 
                   "Expected pc_reg = " & slv_to_hstring(pc_register) & LF &
                   "Observed pc_reg = " & slv_to_hstring(pc_reg) & LF
            severity error;

            err := err + 1;

            end if;

            if (instruction /= instr) then

                report "BRANCH test #" & integer'image(test_nbr) & LF & 
                       "Expected instruction = " & slv_to_hstring(instr) & LF &
                       "Observed instruction = " & slv_to_hstring(instruction) & LF
                severity error;

                err := err + 1;

            end if;

            if (imm(12 downto 0) /= imme) then

                report "BRANCH test #" & integer'image(test_nbr) & LF & 
                       "Expected immediate = " & slv_to_hstring(imme) & LF &
                       "Observed immediate = " & slv_to_hstring(imm(11 downto 0)) & LF
                severity error;
   
                err := err + 1;

            end if;

            if (alu_res_o /= alu_o) then

                report "BRANCH test #" & integer'image(test_nbr) & LF & 
                       "Expected alu_res = " & slv_to_hstring(alu_o) & LF &
                       "Observed alu_res = " & slv_to_hstring(alu_res_o) & LF
                severity error;

                err := err + 1;

            end if;


            if (rs1_o /= rs1_ad) then

                report "BRANCH test #" & integer'image(test_nbr) & LF & 
                       "Expected rs1 = " & slv_to_hstring(rs1_ad) & LF &
                       "Observed rs1 = " & slv_to_hstring(rs1_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (rs2_o /= rs2_ad) then

                report "BRANCH test #" & integer'image(test_nbr) & LF & 
                       "Expected rs1 = " & slv_to_hstring(rs2_ad) & LF &
                       "Observed rs1 = " & slv_to_hstring(rs2_o) & LF
                severity error;

                err := err + 1;

            end if;
            
            if (sign = '0') then

                if ((unsigned(rs1_data_o) < unsigned(rs2_data_o)) and (funct3 = "110")) or
                    ((unsigned(rs1_data_o) >= unsigned(rs2_data_o)) and (funct3 = "111")) then

                    if (pc_src /= BRANCH) then

                        report "PC_source should be equal to BRANCH " & LF &
                        " but got " & pc_src_t'image(pc_src) & LF
                        severity error; 

                        err := err + 1;
                    end if;

                elsif ((unsigned(rs1_data_o) >= unsigned(rs2_data_o)) and (funct3 = "110")) or
                        ((unsigned(rs1_data_o) < unsigned(rs2_data_o)) and (funct3 = "111")) then
                        
                    if (pc_src /= PC_DEFAULT) then

                        report "PC_source should be equal to PC_DEFAULT " & LF &
                        " but got " & pc_src_t'image(pc_src) & LF
                        severity error; 

                        err := err + 1;
                    end if;

                end if;
                
            else    

                if ((signed(rs1_data_o) < signed(rs2_data_o)) and (funct3 = "100"))  or
                    ((signed(rs1_data_o) >= signed(rs2_data_o)) and (funct3 = "101")) or
                    ((signed(rs1_data_o) = signed(rs2_data_o)) and (funct3 = "000"))  or
                    ((signed(rs1_data_o) /= signed(rs2_data_o)) and (funct3 = "001")) then

                    if (pc_src /= BRANCH) then

                        report "PC_source should be equal to BRANCH " & LF &
                        " but got " & pc_src_t'image(pc_src) & LF
                        severity error; 

                        err := err + 1;
                    end if;

                elsif ((signed(rs1_data_o) >= signed(rs2_data_o)) and (funct3 = "100")) or
                        ((signed(rs1_data_o) < signed(rs2_data_o)) and (funct3 = "101"))  or
                        ((signed(rs1_data_o) /= signed(rs2_data_o)) and (funct3 = "000")) or
                        ((signed(rs1_data_o) = signed(rs2_data_o)) and (funct3 = "001"))  then
                        
                    if (pc_src /= PC_DEFAULT) then

                        report "PC_source should be equal to PC_DEFAULT " & LF &
                        " but got " & pc_src_t'image(pc_src) & LF
                        severity error; 

                        err := err + 1;
                    end if;

                end if;

            end if;

            if (err = 0) then

                report "Test #" & integer'image(test_nbr) &" passed!" severity note;
            else 

                report "Test #" & integer'image(test_nbr) & " finished with " & integer'image(err) &
                    " error(s)" 
                    severity error;
            end if;

        end procedure;                    
        

        -- ============================================================================================
        procedure jump_test(  constant test_nbr     : in integer;
                              constant pc_register  : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                              constant instr        : in std_ulogic_vector(31 downto 0);
                              constant imme         : in std_ulogic_vector(20 downto 0);
                              constant alu_o        : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                              constant desti_reg    : in std_ulogic_vector(4 downto 0);
                              variable err          : inout integer) is  
        begin

            if (pc_reg /= pc_register) then

            report "JUMP test #" & integer'image(test_nbr) & LF & 
                   "Expected pc_reg = " & slv_to_hstring(pc_register) & LF &
                   "Observed pc_reg = " & slv_to_hstring(pc_reg) & LF
            severity error;

            err := err + 1;

            end if;

            if (instruction /= instr) then

                report "JUMP test #" & integer'image(test_nbr) & LF & 
                       "Expected instruction = " & slv_to_hstring(instr) & LF &
                       "Observed instruction = " & slv_to_hstring(instruction) & LF
                severity error;

                err := err + 1;

            end if;

            if (imm(20 downto 0) /= imme) then

                report "JUMP test #" & integer'image(test_nbr) & LF & 
                       "Expected immediate = " & slv_to_hstring(imme) & LF &
                       "Observed immediate = " & slv_to_hstring(imm(11 downto 0)) & LF
                severity error;
   
                err := err + 1;

            end if;

            if (alu_res_o /= alu_o) then

                report "JUMP test #" & integer'image(test_nbr) & LF & 
                       "Expected alu_res = " & slv_to_hstring(alu_o) & LF &
                       "Observed alu_res = " & slv_to_hstring(alu_res_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (rd_o /= desti_reg) then

                report "LW test #" & integer'image(test_nbr) & LF & 
                       "Expected rd = " & slv_to_hstring(desti_reg) & LF &
                       "Observed rd = " & slv_to_hstring(rd_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (err = 0) then

                report "Test #" & integer'image(test_nbr) &" passed!" severity note;
            else 

                report "Test #" & integer'image(test_nbr) & " finished with " & integer'image(err) &
                    " error(s)" 
                    severity error;
            end if;

        end procedure;
        
        


        -- ============================================================================================
        procedure   U_test (  constant test_nbr     : in integer;
                              constant pc_register  : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                              constant instr        : in std_ulogic_vector(31 downto 0);
                              constant imme         : in std_ulogic_vector(19 downto 0);
                              constant alu_o        : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                              constant wb_data      : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                              constant desti_reg    : in std_ulogic_vector(4 downto 0);
                              variable err          : inout integer) is  
        begin

            if (pc_reg /= pc_register) then

            report "U type test #" & integer'image(test_nbr) & LF & 
                   "Expected pc_reg = " & slv_to_hstring(pc_register) & LF &
                   "Observed pc_reg = " & slv_to_hstring(pc_reg) & LF
            severity error;

            err := err + 1;

            end if;

            if (instruction /= instr) then

                report "U type test #" & integer'image(test_nbr) & LF & 
                       "Expected instruction = " & slv_to_hstring(instr) & LF &
                       "Observed instruction = " & slv_to_hstring(instruction) & LF
                severity error;

                err := err + 1;

            end if;

            if (imm(31 downto 12) /= imme) then

                report "U type test #" & integer'image(test_nbr) & LF & 
                       "Expected immediate = " & slv_to_hstring(imme) & LF &
                       "Observed immediate = " & slv_to_hstring(imm(11 downto 0)) & LF
                severity error;
   
                err := err + 1;

            end if;

            if (rf_wd /= wb_data) then

                report "U type test #" & integer'image(test_nbr) & LF & 
                       "Expected rf_wdata = " & slv_to_hstring(wb_data) & LF &
                       "Observed rf_wdata = " & slv_to_hstring(rf_wd) & LF
                severity error;

                err := err + 1;

            end if;
            
            if (alu_res_o /= alu_o) then

                report "U type test #" & integer'image(test_nbr) & LF & 
                       "Expected alu_res = " & slv_to_hstring(alu_o) & LF &
                       "Observed alu_res = " & slv_to_hstring(alu_res_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (rd_o /= desti_reg) then

                report "U type test #" & integer'image(test_nbr) & LF & 
                       "Expected rd = " & slv_to_hstring(desti_reg) & LF &
                       "Observed rd = " & slv_to_hstring(rd_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (err = 0) then

                report "Test #" & integer'image(test_nbr) &" passed!" severity note;
            else 

                report "Test #" & integer'image(test_nbr) & " finished with " & integer'image(err) &
                    " error(s)" 
                    severity failure;
            end if;

        end procedure;        

        procedure Rtype_test(  constant test_nbr     : in integer;
                               constant pc_register  : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                               constant instr        : in std_ulogic_vector(31 downto 0);
                               constant rs1_add      : in std_ulogic_vector(4 downto 0);
                               constant rs2_add      : in std_ulogic_vector(4 downto 0);
                               constant rd_add       : in std_ulogic_vector(4 downto 0);
                               constant alu_o        : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                               constant wb_data      : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                               variable err          : inout integer) is  
        begin

            if (pc_reg /= pc_register) then

            report "R type test #" & integer'image(test_nbr) & LF & 
                   "Expected pc_reg = " & slv_to_hstring(pc_register) & LF &
                   "Observed pc_reg = " & slv_to_hstring(pc_reg) & LF
            severity error;

            err := err + 1;

            end if;

            if (instruction /= instr) then

                report "R type test #" & integer'image(test_nbr) & LF & 
                       "Expected instruction = " & slv_to_hstring(instr) & LF &
                       "Observed instruction = " & slv_to_hstring(instruction) & LF
                severity error;

                err := err + 1;

            end if;

            if (rs1_o /= rs1_add) then

                report "R type test #" & integer'image(test_nbr) & LF & 
                       "Expected rs1 adress = " & slv_to_hstring(rs1_add) & LF &
                       "Observed rs1 adress = " & slv_to_hstring(rs1_o) & LF
                severity error;

                err := err + 1;

            end if;
            if (rs2_o /= rs2_add) then

                report "R type test #" & integer'image(test_nbr) & LF & 
                       "Expected rs2 adress = " & slv_to_hstring(rs2_add) & LF &
                       "Observed rs2 adress = " & slv_to_hstring(rs2_o) & LF
                severity error;

                err := err + 1;

            end if;
            
            if (rd_o /= rd_add) then

                report "R type test #" & integer'image(test_nbr) & LF & 
                       "Expected rd adress = " & slv_to_hstring(rd_add) & LF &
                       "Observed rd adress = " & slv_to_hstring(rd_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (alu_res_o /= alu_o) then

                report "R type test #" & integer'image(test_nbr) & LF & 
                       "Expected alu_res = " & slv_to_hstring(alu_o) & LF &
                       "Observed alu_res = " & slv_to_hstring(alu_res_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (rf_wd /= wb_data) then

                report "R type test #" & integer'image(test_nbr) & LF & 
                       "Expected rf_wdata = " & slv_to_hstring(wb_data) & LF &
                       "Observed rf_wdata = " & slv_to_hstring(rf_wd) & LF
                severity error;

                err := err + 1;

            end if;

            if (err = 0) then

                report "Test #" & integer'image(test_nbr) &" passed!" severity note;
            else 

                report "Test #" & integer'image(test_nbr) & " finished with " & integer'image(err) &
                    " error(s)" 
                    severity error;
            end if;

        end procedure;


        procedure Itype_test(  constant test_nbr     : in integer;
                               constant pc_register  : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                               constant instr        : in std_ulogic_vector(31 downto 0);
                               constant rs1_add      : in std_ulogic_vector(4 downto 0);
                               constant imme         : in std_ulogic_vector(11 downto 0);
                               constant rd_add       : in std_ulogic_vector(4 downto 0);
                               constant alu_o        : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                               constant wb_data      : in std_ulogic_vector(DATA_WIDTH - 1 downto 0);
                               variable err          : inout integer) is  
        begin

            if (pc_reg /= pc_register) then

            report "I type test #" & integer'image(test_nbr) & LF & 
                   "Expected pc_reg = " & slv_to_hstring(pc_register) & LF &
                   "Observed pc_reg = " & slv_to_hstring(pc_reg) & LF
            severity error;

            err := err + 1;

            end if;

            if (instruction /= instr) then

                report "I type test #" & integer'image(test_nbr) & LF & 
                       "Expected instruction = " & slv_to_hstring(instr) & LF &
                       "Observed instruction = " & slv_to_hstring(instruction) & LF
                severity error;

                err := err + 1;

            end if;

            if (rs1_o /= rs1_add) then

                report "I type test #" & integer'image(test_nbr) & LF & 
                       "Expected rs1 adress = " & slv_to_hstring(rs1_add) & LF &
                       "Observed rs1 adress = " & slv_to_hstring(rs1_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (imm(11 downto 0) /= imme) then

                report "I type test #" & integer'image(test_nbr) & LF & 
                       "Expected immediate = " & slv_to_hstring(imme) & LF &
                       "Observed immediate = " & slv_to_hstring(imm(11 downto 0)) & LF
                severity error;
   
                err := err + 1;

            end if;
            
            if (rd_o /= rd_add) then

                report "I type test #" & integer'image(test_nbr) & LF & 
                       "Expected rd adress = " & slv_to_hstring(rd_add) & LF &
                       "Observed rd adress = " & slv_to_hstring(rd_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (alu_res_o /= alu_o) then

                report "I type test #" & integer'image(test_nbr) & LF & 
                       "Expected alu_res = " & slv_to_hstring(alu_o) & LF &
                       "Observed alu_res = " & slv_to_hstring(alu_res_o) & LF
                severity error;

                err := err + 1;

            end if;

            if (rf_wd /= wb_data) then

                report "I type test #" & integer'image(test_nbr) & LF & 
                       "Expected rf_wdata = " & slv_to_hstring(wb_data) & LF &
                       "Observed rf_wdata = " & slv_to_hstring(rf_wd) & LF
                severity error;

                err := err + 1;

            end if;

            if (err = 0) then

                report "Test #" & integer'image(test_nbr) &" passed!" severity note;
            else 

                report "Test #" & integer'image(test_nbr) & " finished with " & integer'image(err) &
                    " error(s)" 
                    severity error;
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

            for i in 0 to 12 loop 

                imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

                assert imem_index < INST_DEPTH 
                    report "imem index is higher than the instruction memory size!" severity failure;

                instruct     := imem_copy(imem_index);
                rs1_i        := instruct(19 downto 15);
                rd_i         := instruct(11 downto 7);
                immediate  := (others => instruct(31));
                immediate(11 downto 0) := instruct(31 downto 20);
                alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate));
                reg_index    := to_int(rd_i);
                dmem_index   := to_int(alu_resultat)/BYTES_PER_WORD;

                assert dmem_index < DATA_DEPTH 
                    report "dmem index is higher than the data memory size!" severity failure;

                rf_wdata     := dmem_copy(dmem_index);
                error_count  := 0;
            
                lw_test(i, pc_rg, instruct, immediate(11 downto 0), alu_resultat, rs1_i, rd_i, rf_wdata, error_count);
        
                wait until rising_edge(clk);
                wait for 1 ns;

                pc_rg        := std_ulogic_vector(unsigned(pc_rg ) + 4);

            end loop;

            if (error_count = 0) then

                report "ALL LW TEST PASSED!" severity note;
            
            else 
                report "Test LW finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

        
        -- ================================================================
        -- SAVE WORD INSTRUCTION TEST
        -- ================================================================
            
            for i in 13 to 19 loop 

                imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

                assert imem_index < INST_DEPTH 
                    report "imem index is higher than the instruction memory size!" severity failure;

                instruct     := imem_copy(imem_index);
                rs1_i        := instruct(19 downto 15);
                rs2_i        := instruct(24 downto 20);
                immediate  := (others => instruct(31));
                immediate(11 downto 0) := instruct(31 downto 25) & instruct(11 downto 7);

                alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate));
                dmem_index   := to_int(alu_resultat)/BYTES_PER_WORD;

                assert dmem_index < DATA_DEPTH 
                    report "dmem index is higher than the data memory size!" severity failure;

                error_count   := 0;
            
                sw_test(i, pc_rg, instruct, immediate(11 downto 0), alu_resultat, rs1_i, rs2_i, error_count);
                
                wait until rising_edge(clk);
                wait for 1 ns;

                pc_rg        := std_ulogic_vector(unsigned(pc_rg ) + 4);

            end loop;

            if (error_count = 0) then

                report "ALL SW TEST PASSED!" severity note;
            else 
                report "Test SW finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;
        
        -- ================================================================
        -- BRANCH INSTRUCTION TEST
        -- ================================================================
            
            for i in 20 to 44 loop 

                imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

                assert imem_index < INST_DEPTH 
                    report "imem index is higher than the instruction memory size!" severity failure;

                instruct        := imem_copy(imem_index);
                rs1_i           := instruct(19 downto 15);
                rs2_i           := instruct(24 downto 20);
                immediate     := (others => instruct(31));
                immediate(12) := instruct(31);
                immediate(11) := instruct(7);
                immediate(10 downto 5) := instruct(30 downto 25);
                immediate(4 downto 1)  := instruct(11 downto 8);
                immediate(0) := '0';

                alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) - unsigned(rs2_data_o));
                error_count   := 0;
            
                branch_test(i, pc_rg, instruct, immediate(12 downto 0), alu_resultat, rs1_i, rs2_i, instruct(14 downto 12), error_count);
                
                if (pc_src = BRANCH) then
                    pc_rg := std_ulogic_vector(unsigned(pc_rg) + unsigned(immediate));
                else 
                    pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);
                end if;

                wait until rising_edge(clk);
                wait for 1 ns;

            end loop;

            if (error_count = 0) then

                report "ALL BRANCH TEST PASSED!" severity note;
            else 
                report "Test BRANCH finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;
        
        -- ================================================================
        -- JUMP INSTRUCTION TEST
        -- ================================================================
            
            -- JAL INSTRUCTION TEST 

            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            immediate(31 downto 20) := (others => instruct(31));
            immediate(20) := instruct(31);
            immediate(11) := instruct(20);
            immediate(10 downto 1) := instruct(30 downto 21);
            immediate(19 downto 12)  := instruct(19 downto 12);
            immediate(0) := '0';

            alu_resultat := (others => '0');
            error_count   := 0;
        
            jump_test(45, pc_rg, instruct, immediate(20 downto 0), alu_resultat,rd_i, error_count);
            
            if (pc_src = JUMP) then
                pc_rg := std_ulogic_vector(unsigned(pc_rg) + unsigned(immediate));
            else 
                pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);
            end if;

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "JAL TEST PASSED!" severity note;
            else 
                report "Test JAL finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;
            
            -- JALR INSTRUCTION test 


            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);


            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate));
            error_count   := 0;
        
            jump_test(46, pc_rg, instruct, immediate(20 downto 0), alu_resultat,rd_i, error_count);
            
            if (pc_src = JUMP) then
                pc_rg := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate));
            else 
                pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);
            end if;

            if (error_count = 0) then

                report "JALR TEST PASSED!" severity note;
            else 
                report "Test JALR finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;
            
            wait until rising_edge(clk);
            wait for 1 ns;
            
            -- JAL INSTRUCTION TEST 

            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            immediate(31 downto 20) := (others => instruct(31));
            immediate(20) := instruct(31);
            immediate(11) := instruct(20);
            immediate(10 downto 1) := instruct(30 downto 21);
            immediate(19 downto 12)  := instruct(19 downto 12);
            immediate(0) := '0';

            alu_resultat := (others => '0');
            error_count   := 0;
        
            jump_test(47, pc_rg, instruct, immediate(20 downto 0), alu_resultat,rd_i, error_count);
            
            if (pc_src = JUMP) then
                pc_rg := std_ulogic_vector(unsigned(pc_rg) + unsigned(immediate));
            else 
                pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);
            end if;

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "JAL TEST PASSED!" severity note;
            else 
                report "Test JAL finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- JALR INSTRUCTION test 


            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);


            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate));
            error_count   := 0;
        
            jump_test(48, pc_rg, instruct, immediate(20 downto 0), alu_resultat,rd_i, error_count);
            
            if (pc_src = JUMP) then
                pc_rg := alu_resultat;
            else 
                pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);
            end if;

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "JALR TEST PASSED!" severity note;
            else 
                report "Test JALR finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- LUI INSTRUCTION test 


            for i in 49 to 52 loop 

                imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

                assert imem_index < INST_DEPTH 
                    report "imem index is higher than the instruction memory size!" severity failure;

                instruct        := imem_copy(imem_index);
                rd_i := instruct(11 downto 7);
                immediate(31 downto 12) := instruct(31 downto 12);
                immediate(11 downto 0) := (others => '0');
                rf_wdata := immediate;
                alu_resultat := (others => '0');
                error_count   := 0;
                
                U_test(i, pc_rg, instruct, immediate(31 downto 12),alu_resultat, rf_wdata, rd_i, error_count);

                pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

                wait until rising_edge(clk);
                wait for 1 ns;

            end loop;
            
            if (error_count = 0) then

                report "ALL LUI TEST PASSED!" severity note;
            else 
                report "Test LUI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;


            -- AUIPC INSTRUCTION test 


            for i in 53 to 54 loop 

                imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

                assert imem_index < INST_DEPTH 
                    report "imem index is higher than the instruction memory size!" severity failure;

                instruct        := imem_copy(imem_index);
                rd_i := instruct(11 downto 7);
                immediate(31 downto 12) := instruct(31 downto 12);
                immediate(11 downto 0) := (others => '0');
                alu_resultat := (others => '0');
                rf_wdata := std_ulogic_vector(unsigned(pc_rg) + unsigned(immediate));

                error_count   := 0;
            
                U_test(i, pc_rg, instruct, immediate(31 downto 12),alu_resultat, rf_wdata, rd_i, error_count);
                
                pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);


                wait until rising_edge(clk);
                wait for 1 ns;

            end loop;

            if (error_count = 0) then

                report "ALL AUIPC TEST PASSED!" severity note;
            else 
                report "Test AUIPC finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;
            
            -- R TYPE INSTRUCTION test 
            

            -- ADD 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(rs2_data_o));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(55, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;
            

            if (error_count = 0) then

                report "ADD TEST PASSED!" severity note;
            else 
                report "Test ADD finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SUB 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) - unsigned(rs2_data_o));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(56, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SUB TEST PASSED!" severity note;
            else 
                report "Test SUB finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- AND 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := rs1_data_o and rs2_data_o;
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(57, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "AND TEST PASSED!" severity note;
            else 
                report "Test AND finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- OR 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := rs1_data_o or rs2_data_o;
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(58, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "OR TEST PASSED!" severity note;
            else 
                report "Test OR finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- XOR 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := rs1_data_o xor rs2_data_o;
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(59, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            
            if (error_count = 0) then

                report "XOR TEST PASSED!" severity note;
            else 
                report "Test XOR finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SLT 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := (others => '0');

            if signed(rs1_data_o) < signed(rs2_data_o) then

                alu_resultat(0) := '1';

            end if;

            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(60, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SLT TEST PASSED!" severity note;
            else 
                report "Test SLT finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;
            
            -- SLTU 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := (others => '0');

            if unsigned(rs1_data_o) < unsigned(rs2_data_o) then

                alu_resultat(0) := '1';

            end if;

            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(61, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SLTU TEST PASSED!" severity note;
            else 
                report "Test SLTU finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SLL 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := std_ulogic_vector(shift_left(unsigned(rs1_data_o), to_int(rs2_data_o)));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(62, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SLL TEST PASSED!" severity note;
            else 
                report "Test SLL finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SRL 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
            alu_resultat := std_ulogic_vector(shift_right(unsigned(rs1_data_o), to_int(rs2_data_o)));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(63, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SRL TEST PASSED!" severity note;
            else 
                report "Test SRL finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SRA 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            rs2_i := instruct(24 downto 20);
    
            alu_resultat := std_ulogic_vector(shift_right(signed(rs1_data_o), to_int(rs2_data_o)));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Rtype_test(64, pc_rg, instruct, rs1_i, rs2_i, rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SRA TEST PASSED!" severity note;
            else 
                report "Test SRA finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;


            -- I TYPE INSTRUCTION test 
            

            -- ADDI 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
            alu_resultat := std_ulogic_vector(unsigned(rs1_data_o) + unsigned(immediate));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(65, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;
            

            if (error_count = 0) then

                report "ADDI TEST PASSED!" severity note;
            else 
                report "Test ADDI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            
            -- ANDI 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
            alu_resultat := rs1_data_o and immediate;
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(66, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "ANDI TEST PASSED!" severity note;
            else 
                report "Test ANDI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- ORI 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
            alu_resultat := rs1_data_o or immediate;
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(67, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "ORI TEST PASSED!" severity note;
            else 
                report "Test ORI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- XORI 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
            alu_resultat := rs1_data_o xor immediate;
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(68, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            
            if (error_count = 0) then

                report "XORI TEST PASSED!" severity note;
            else 
                report "Test XORI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SLTI 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
            alu_resultat := (others => '0');

            if signed(rs1_data_o) < signed(immediate) then

                alu_resultat(0) := '1';

            end if;

            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(69, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SLTI TEST PASSED!" severity note;
            else 
                report "Test SLTI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;
            
            -- SLTIU 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
            alu_resultat := (others => '0');

            if unsigned(rs1_data_o) < unsigned(immediate) then

                alu_resultat(0) := '1';

            end if;

            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(70, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SLTUI TEST PASSED!" severity note;
            else 
                report "Test SLTUI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SLLI 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
            alu_resultat := std_ulogic_vector(shift_left(unsigned(rs1_data_o), to_int(immediate)));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(71, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SLLI TEST PASSED!" severity note;
            else 
                report "Test SLLI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SRLI 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
            alu_resultat := std_ulogic_vector(shift_right(unsigned(rs1_data_o), to_int(immediate)));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(72, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SRLI TEST PASSED!" severity note;
            else 
                report "Test SRLI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;

            -- SRAI 
            imem_index   := to_int(pc_rg)/BYTES_PER_WORD;

            assert imem_index < INST_DEPTH 
                report "imem index is higher than the instruction memory size!" severity failure;

            instruct        := imem_copy(imem_index);
            rd_i := instruct(11 downto 7);
            rs1_i := instruct(19 downto 15);
            immediate(31 downto 12) := (others => instruct(31));
            immediate(11 downto 0) := instruct(31 downto 20);
    
            alu_resultat := std_ulogic_vector(shift_right(signed(rs1_data_o), to_int(immediate)));
            rf_wdata := alu_resultat;

            error_count   := 0;
        
            Itype_test(73, pc_rg, instruct, rs1_i, immediate(11 downto 0), rd_i, alu_resultat, rf_wdata, error_count);
            
            pc_rg := std_ulogic_vector(unsigned(pc_rg ) + 4);

            wait until rising_edge(clk);
            wait for 1 ns;

            if (error_count = 0) then

                report "SRAI TEST PASSED!" severity note;
            else 
                report "Test SRAI finished with " & integer'image(error_count) & " error(s)."
                severity failure;
            end if;


            wait until rising_edge(clk);
            wait for 1 ns;

	if (error_count = 0) then

           report "ALL TESTS PASSED!" severity note;
        else 
           report "Test finished with " & integer'image(error_count) & " error(s)."
           severity failure;
        end if;


        assert false
            report "End of simulation"
            severity failure;

    end process STIM;


end architecture sim;