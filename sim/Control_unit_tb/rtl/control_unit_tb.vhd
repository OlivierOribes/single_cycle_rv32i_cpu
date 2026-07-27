 --==============================================================================
--  Module      : Control unit
--  File        : control_unit_tb.vhd
--  Description : Control unit testbench for validation through simulation
--
--
--  Author      : Olivier Oribes
--  Created     : 19/07/2026
--  Last update : 19/07/2026
--
--  Version     : 1.0
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--
--  Parameters:
--      INS_SIZE : Instruction size (in bits)
--
--  Ports:
--      instruction : input  std_ulogic_vector[INS_SIZE-1:0] - current instruction
--      ALU_ctrl    : output std_ulogic_vector[3:0]  - 4-bit ALU opcode
--      ALU_src     : output std_ulogic              - selects register (0) or immediate (1) as ALU source
--      reg_write   : output std_ulogic              - write enable for register file module
--      mem_en_o    : output std_ulogic              - memory access enable
--      mem_rw_o    : output std_ulogic              - read/write select for data memory (0 = read, 1 = write)
--      mem_to_reg    : output std_ulogic            - selects write-back data (0 = ALU result, 1 = memory read data)
--      raw_src     : output std_logic_vector[24:0]  - instruction bits with opcode (6:0) removed
--      inst_code   : output std_logic_vector[6:0]   - instruction opcode (identifies type: R,I,S,U,J)
--      rs1         : output std_logic_vector[4:0]   - source register 1
--      rs2         : output std_logic_vector[4:0]   - source register 2
--      rd          : output std_logic_vector[4:0]   - destination register
--
--  License: MIT (see LICENSE file)
--      
--
--==============================================================================

library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cpu_pkg.all;


entity control_unit_tb is
end entity control_unit_tb;

architecture sim of control_unit_tb is

    -- ------------------------------------------------------------------
    -- Constants / signals
    -- ------------------------------------------------------------------
    constant INS_SIZE  : integer := 32; -- Instruction size (default : 32 bits)
    signal instruction : std_ulogic_vector(INS_SIZE - 1 downto 0);
    signal ALU_ctrl    : std_ulogic_vector(3 downto 0);        -- ALU opcode
    signal ALU_src     : std_ulogic;                           -- enable or disable immediate using MUX
    signal reg_write   : std_ulogic;                           -- enable write mode in register file
    signal mem_en_o    : std_ulogic;                           -- memory access enable
    signal mem_rw_o    : std_ulogic;                           -- enable read/write in data memory, 0 = read, 1 = write
    signal mem_to_reg  : std_ulogic;                           -- Multiplexer selecting the data written back to the register file (ALU result or memory read data).
    signal raw_src     : std_ulogic_vector(24 downto 0);       -- Instruction once opcode (6 downto 0) is removed from it
    signal inst_code   : std_ulogic_vector(6 downto 0);        -- Give the type of instruction (R,I,S,U,J)
    signal rs1         : std_ulogic_vector(4 downto 0);        -- source register 1
    signal rs2         : std_ulogic_vector(4 downto 0);        -- source register 2
    signal rd          : std_ulogic_vector(4 downto 0);        -- destination register

begin

    -- ------------------------------------------------------------------
    -- DUT
    -- ------------------------------------------------------------------
    DUT : entity work.control_unit
    generic map (
      INS_SIZE => INS_SIZE
    )
    port map (
      instruction => instruction,
      ALU_ctrl    => ALU_ctrl,
      ALU_src     => ALU_src,
      reg_write   => reg_write,
      mem_en_o    => mem_en_o,
      mem_rw_o    => mem_rw_o,
      mem_to_reg  => mem_to_reg,
      raw_src     => raw_src,
      inst_code   => inst_code,
      rs1         => rs1,
      rs2         => rs2,
      rd          => rd
    );


    -- ------------------------------------------------------------------
    -- Stimulus
    -- ------------------------------------------------------------------
    STIM : process

        constant N              : integer := 1000;
        constant seed           : std_ulogic_vector(31 downto 0) := x"FA04_BCDE";
        constant ZERO           : std_ulogic_vector(4 downto 0)  := (others => '0');
        variable total_error    : integer := 0;
        variable randvec        : std_ulogic_vector(31 downto 0) := seed;
        variable func3          : std_ulogic_vector(2 downto 0);
        variable func7          : std_ulogic_vector(6 downto 0);
        variable ALU_code       : std_ulogic_vector(3 downto 0);

        constant R_type         : std_ulogic_vector(6 downto 0) := "0110011";
        constant I_type         : std_ulogic_vector(6 downto 0) := "0000011";
        variable inst_typ       : std_ulogic_vector(6 downto 0) := (others => '0');

        procedure R_type_test(constant funct3   : in std_ulogic_vector(2 downto 0);
                              constant funct7   : in std_ulogic_vector(6 downto 0);
                              constant ALU_op   : in std_ulogic_vector(3 downto 0);
                              constant ope      : in string;
                              variable err    : inout integer) is  
        begin

            for i in 0 to N loop

                randvec := lfsr(randvec);

                instruction <= funct7 & randvec(24 downto 15) &
                            funct3 & randvec(11 downto 7) & R_type;
                
                wait for 1 ns;

                if (rs1 /= instruction(19 downto 15)) then
                
                    report "rs1 output should be equal to " & slv_to_hstring(instruction(19 downto 15)) & LF &
                        " but got " & slv_to_hstring(rs1) & LF
                            severity error; 

                    err := err + 1; 

                end if;
                
                if (rs2 /= instruction(24 downto 20)) then

                    report "rs2 output should be equal to " & slv_to_hstring(instruction(24 downto 20)) & LF &
                        " but got " & slv_to_hstring(rs2) & LF
                            severity error; 

                    err := err + 1; 

                end if;


                if (rd /= instruction(11 downto 7)) then

                    report "rd output should be equal to " & slv_to_hstring(instruction(11 downto 7)) & LF &
                        " but got " & slv_to_hstring(rd) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (raw_src /= instruction(INS_SIZE - 1 downto 7)) then

                    report "raw_src output should be equal to " & slv_to_hstring(instruction(INS_SIZE -1 downto 7)) & LF &
                        " but got " & slv_to_hstring(raw_src) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (ALU_src /= '0') then

                    report "ALU_src output should be equal to 0 " & LF &
                        " but got " & std_ulogic'image(ALU_src) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (ALU_ctrl /= ALU_op) then

                    report "ALU_ctrl output should be equal to " & slv_to_hstring(ALU_op) & LF &
                        " but got " & slv_to_hstring(ALU_ctrl) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (mem_en_o /= '0') then

                    report "mem_en_o output should be equal to 0 " & LF &
                        " but got " & std_ulogic'image(mem_en_o) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (mem_rw_o /= '0') then

                    report "mem_rw_o output should be equal to 0 " & LF &
                        " but got " & std_ulogic'image(mem_rw_o) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (mem_to_reg /= '0') then

                    report "mem_to_reg output should be equal to 0 " & LF &
                        " but got " & std_ulogic'image(mem_to_reg) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (reg_write /= '1') then

                    report "reg_write output should be equal to 1 " & LF &
                        " but got " & std_ulogic'image(reg_write) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (inst_code /= R_type) then

                    report "inst_code output should be equal to " & slv_to_hstring(R_type) & LF &
                        " but got " & slv_to_hstring(inst_code) & LF
                            severity error; 

                    err := err + 1; 

                end if;
                    
            end loop;

            if (err = 0) then
                    report ope & " TEST PASSED!" severity note;
                
            else
                report ope & " TEST FINISHED WITH " &
                        integer'image(err) & " ERROR(S)"
                        severity failure;
            end if;

        end procedure;

        procedure type_unknown  (constant funct3   : in std_ulogic_vector(2 downto 0);
                                 constant funct7   : in std_ulogic_vector(6 downto 0);
                                 constant ALU_op   : in std_ulogic_vector(3 downto 0);
                                 constant ins_typ  : in std_ulogic_vector(6 downto 0);
                                 variable err      : inout integer) is  
        begin

            case (ins_typ) is

                when (R_type) =>
                    instruction <= funct7 & randvec(24 downto 15) &
                                funct3 & randvec(11 downto 7) & R_type;
                
                when (I_type) => 
                    instruction <= randvec(31 downto 15) & funct3 &
                            randvec(11 downto 7) & I_type;
                
                when others =>

                    instruction <= randvec(31 downto 7) & ins_typ;

            end case;
            
            wait for 1 ns;
            
            if ((ins_typ = R_type) or (ins_typ = I_type)) then

                if (rs1 /= instruction(19 downto 15)) then
                
                    report "rs1 output should be equal to " & slv_to_hstring(instruction(19 downto 15)) & LF &
                        " but got " & slv_to_hstring(rs1) & LF
                            severity error; 

                    err := err + 1; 

                end if;
            
            else 
                if (rs1 /= ZERO) then
            
                report "rs1 output should be equal to " & slv_to_hstring(ZERO) & LF &
                    " but got " & slv_to_hstring(rs1) & LF
                        severity error; 

                err := err + 1; 

                end if;
            
            end if;
                    
            if (ins_typ = R_type) then
                
                if (rs2 /= instruction(24 downto 20)) then

                    report "rs2 output should be equal to " & slv_to_hstring(instruction(24 downto 20)) & LF &
                        " but got " & slv_to_hstring(rs2) & LF
                            severity error; 

                    err := err + 1; 

                end if;
            
            else 

                if (rs2 /= ZERO) then

                    report "rs2 output should be equal to " & slv_to_hstring(ZERO) & LF &
                        " but got " & slv_to_hstring(rs2) & LF
                            severity error; 

                    err := err + 1; 

                end if;

            end if;
            
            if ((ins_typ = R_type) or (ins_typ = I_type)) then
                if (rd /= instruction(11 downto 7)) then

                    report "rd output should be equal to " & slv_to_hstring(instruction(11 downto 7)) & LF &
                        " but got " & slv_to_hstring(rd) & LF
                            severity error; 

                    err := err + 1; 

                end if;
            
            else 
                if (rd /= ZERO) then
            
                report "rd output should be equal to " & slv_to_hstring(ZERO) & LF &
                    " but got " & slv_to_hstring(rd) & LF
                        severity error; 

                err := err + 1; 

                end if;
            
            end if;

            if (raw_src /= instruction(INS_SIZE - 1 downto 7)) then

                report "raw_src output should be equal to " & slv_to_hstring(instruction(INS_SIZE - 1 downto 7)) & LF &
                    " but got " & slv_to_hstring(raw_src) & LF
                        severity error; 

                err := err + 1; 

            end if;

            if (ALU_src /= '0') then

                report "ALU_src output should be equal to 0 " & LF &
                    " but got " & std_ulogic'image(ALU_src) & LF
                        severity error; 

                err := err + 1; 

            end if;

            if (ALU_ctrl /= ALU_op) then

                report "ALU_ctrl output should be equal to " & slv_to_hstring(ALU_op) & LF &
                    " but got " & slv_to_hstring(ALU_ctrl) & LF
                        severity error; 

                err := err + 1; 

            end if;

            if (mem_en_o /= '0') then

                report "mem_en_o output should be equal to 0 " & LF &
                    " but got " & std_ulogic'image(mem_en_o) & LF
                        severity error; 

                err := err + 1; 

            end if;

            if (mem_rw_o /= '0') then

                report "mem_rw_o output should be equal to 0 " & LF &
                    " but got " & std_ulogic'image(mem_rw_o) & LF
                        severity error; 

                err := err + 1; 

            end if;

            if (mem_to_reg /= '0') then

                report "mem_to_reg output should be equal to 0 " & LF &
                    " but got " & std_ulogic'image(mem_to_reg) & LF
                        severity error; 

                err := err + 1; 

            end if;

            if (reg_write /= '0') then

                report "reg_write output should be equal to 0 " & LF &
                    " but got " & std_ulogic'image(reg_write) & LF
                        severity error; 

                err := err + 1; 

            end if;

            if (inst_code /= ins_typ) then

                report "inst_code output should be equal to " & slv_to_hstring(ins_typ) & LF &
                    " but got " & slv_to_hstring(inst_code) & LF
                        severity error; 

                err := err + 1; 

            end if;
        

        end procedure;


        procedure load_instr_test(constant funct3   : in std_ulogic_vector(2 downto 0);
                                  constant ALU_op   : in std_ulogic_vector(3 downto 0);
                                  constant ope      : in string;
                                  variable err    : inout integer) is  
        begin

            for i in 0 to N loop

                randvec := lfsr(randvec);

                instruction <= randvec(31 downto 15) & funct3 &
                               randvec(11 downto 7) & I_type;
                
                wait for 1 ns;

                if (rs1 /= instruction(19 downto 15)) then
                
                    report "rs1 output should be equal to " & slv_to_hstring(instruction(19 downto 15)) & LF &
                        " but got " & slv_to_hstring(rs1) & LF
                            severity error; 

                    err := err + 1; 

                end if;
                
                if (rs2 /= ZERO) then

                    report "rs2 output should be equal to " & slv_to_hstring(ZERO) & LF &
                        " but got " & slv_to_hstring(rs2) & LF
                            severity error; 

                    err := err + 1; 

                end if;


                if (rd /= instruction(11 downto 7)) then

                    report "rd output should be equal to " & slv_to_hstring(instruction(11 downto 7)) & LF &
                        " but got " & slv_to_hstring(rd) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (raw_src /= instruction(INS_SIZE - 1 downto 7)) then

                    report "raw_src output should be equal to " & slv_to_hstring(instruction(INS_SIZE -1 downto 7)) & LF &
                        " but got " & slv_to_hstring(raw_src) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (ALU_src /= '1') then

                    report "ALU_src output should be equal to 1 " & LF &
                        " but got " & std_ulogic'image(ALU_src) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (ALU_ctrl /= ALU_op) then

                    report "ALU_ctrl output should be equal to " & slv_to_hstring(ALU_op) & LF &
                        " but got " & slv_to_hstring(ALU_ctrl) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (mem_en_o /= '1') then

                    report "mem_en_o output should be equal to 1 " & LF &
                        " but got " & std_ulogic'image(mem_en_o) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (mem_rw_o /= '0') then

                    report "mem_rw_o output should be equal to 0 " & LF &
                        " but got " & std_ulogic'image(mem_rw_o) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (mem_to_reg /= '1') then

                    report "mem_to_reg output should be equal to 1 " & LF &
                        " but got " & std_ulogic'image(mem_to_reg) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (reg_write /= '1') then

                    report "reg_write output should be equal to 1 " & LF &
                        " but got " & std_ulogic'image(reg_write) & LF
                            severity error; 

                    err := err + 1; 

                end if;

                if (inst_code /= I_type) then

                    report "inst_code output should be equal to " & slv_to_hstring(I_type) & LF &
                        " but got " & slv_to_hstring(inst_code) & LF
                            severity error; 

                    err := err + 1; 

                end if;
                  
            end loop;

            if (err = 0) then
                    report ope & " TEST PASSED!" severity note;
                
            else
                report ope & " TEST FINISHED WITH " &
                        integer'image(err) & " ERROR(S)"
                        severity failure;
            end if;

        end procedure;


    begin

        -- -------------------------------------------------------------------
        -- Test 1 : ADD operation
        -- -------------------------------------------------------------------

        func3        := "000";
        func7        := "0000000";
        ALU_code     := "0010";
        
        R_type_test(func3, func7, ALU_code, "ADD", total_error);

        -- -------------------------------------------------------------------
        -- Test 2 : AND operation
        -- -------------------------------------------------------------------

        func3        := "111";
        func7        := "0000000";
        ALU_code     := "0000";
        
        R_type_test(func3, func7, ALU_code, "AND", total_error);

        -- -------------------------------------------------------------------
        -- Test 3 : OR operation
        -- -------------------------------------------------------------------

        func3        := "110";
        func7        := "0000000";
        ALU_code     := "0001";

        R_type_test(func3, func7, ALU_code, "OR", total_error);

        -- -------------------------------------------------------------------
        -- Test 4 : XOR operation
        -- -------------------------------------------------------------------

        func3        := "100";
        func7        := "0000000";
        ALU_code     := "0011";

        R_type_test(func3, func7, ALU_code, "XOR", total_error);

        -- -------------------------------------------------------------------
        -- Test 5 : SLT operation
        -- -------------------------------------------------------------------

        func3        := "010";
        func7        := "0000000";
        ALU_code     := "0111";

        R_type_test(func3, func7, ALU_code, "SLT", total_error);

        -- -------------------------------------------------------------------
        -- Test 6 : SLL operation
        -- -------------------------------------------------------------------

        func3        := "001";
        func7        := "0000000";
        ALU_code     := "1101";
        
        R_type_test(func3, func7, ALU_code, "SLL", total_error);

        -- -------------------------------------------------------------------
        -- Test 7 : SRL operation
        -- -------------------------------------------------------------------

        func3        := "101";
        func7        := "0000000";
        ALU_code     := "1110";
        
        R_type_test(func3, func7, ALU_code, "SRL", total_error);

        -- -------------------------------------------------------------------
        -- Test 8 : SUB operation
        -- -------------------------------------------------------------------

        func3        := "000";
        func7        := "0100000";
        ALU_code     := "0110";
        
        R_type_test(func3, func7, ALU_code, "SUB", total_error);

        -- -------------------------------------------------------------------
        -- Test 9 : LOAD WORD operation
        -- -------------------------------------------------------------------

        func3        := "010";
        ALU_code     := "0010";
        
        load_instr_test(func3, ALU_code, "LW ", total_error);


        -- -------------------------------------------------------------------
        -- Test 10 : Unknown R type operation
        -- -------------------------------------------------------------------

        for i in 0 to N loop 

            randvec      := lfsr(randvec);
            func3        := randvec(2 downto 0);
            func7        := '1' & randvec(5 downto 0);
            ALU_code     := "0000";
        
            type_unknown(func3, func7, ALU_code, R_type, total_error);

        end loop;

        if (total_error = 0) then
                    report "TEST PASSED!" severity note;
                
        else
            report "TEST FINISHED WITH " &
                    integer'image(total_error) & " ERROR(S)"
                    severity failure;
        end if;


        -- -------------------------------------------------------------------
        -- Test 11 : Unknown I type operation
        -- -------------------------------------------------------------------

        for i in 0 to N loop 
            
            randvec      := lfsr(randvec);
            func3        := randvec(2) & '0' & randvec(0);
            func7        := '1' & randvec(5 downto 0);
            ALU_code     := "0000";
        
            type_unknown(func3, func7, ALU_code, I_type, total_error);
            
        end loop;

        
        if (total_error = 0) then
                    report "TEST PASSED!" severity note;
                
        else
            report "TEST FINISHED WITH " &
                    integer'image(total_error) & " ERROR(S)"
                    severity failure;
        end if;

        -- -------------------------------------------------------------------
        -- Test 12 : Unknown op code
        -- -------------------------------------------------------------------

        for i in 0 to N loop 

            loop
                randvec      := lfsr(randvec);
                func3        := randvec(2 downto 0);
                func7        := '1' & randvec(5 downto 0);
                inst_typ     := '1' & randvec(5 downto 0);

                exit when not ((inst_typ = R_type) or (inst_typ = I_type));
            end loop;

            ALU_code     := "0000";
        
            type_unknown(func3, func7, ALU_code, inst_typ, total_error);
            
        end loop;


        if (total_error = 0) then
            report "ALL TEST PASSED!" severity note;
        
        else
            report "SIMULATION FINISHED WITH " &
                    integer'image(total_error) & " ERROR(S)"
                    severity failure;
        end if;


        report "End of simulation" severity note;
        wait;

    end process STIM;

end architecture sim;