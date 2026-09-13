--==============================================================================
--  Module      : Control unit
--  File        : control_unit.vhd
--  Description : Decodes the current instruction and generates the control
--                signals used by the datapath: ALU opcode, immediate/register
--                ALU source select, next-PC source (branch/jump), write-back
--                source select, JALR target select, U-type select, byte
--                enables and sign for loads/stores, register-file write
--                enable, along with the extracted instruction fields
--                (opcode, funct fields, register indexes). Supports R-type,
--                I-type ALU, LW/SW (with byte/half-word variants), all
--                branches, JAL, JALR, LUI and AUIPC.
--
--
--  Author      : Olivier Oribes
--  Created     : 17/07/2026
--  Last update : 02/09/2026
--
--  Version     : 1.2
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--
--
--  Ports:
--      instruction   : input  std_ulogic_vector(DATA_WIDTH-1 downto 0) - current instruction
--      alu_status    : input  std_ulogic_vector(5 downto 0)   - (Byte select, C, Z, N, V)
--      alu_ctrl      : output alu_op_t                        - ALU operation
--      alu_src       : output std_ulogic                      - selects register (0) or immediate (1) as ALU source
--      PC_src        : output pc_src_t                        - selects next PC source (default/branch/jump)
--      reg_write     : output std_ulogic                      - write enable for register file module
--      mem_en_o      : output std_ulogic                      - memory access enable
--      mem_rw_o      : output std_ulogic                      - read/write select for data memory (0 = read, 1 = write)
--      wb_src        : output std_ulogic_vector(1 downto 0)   - write-back source select (00 ALU, 01 mem, 10 pc+4, 11 immediate/U-type)
--      jalr_sel      : output std_ulogic                      - selects JALR target (rs1+imm) vs JAL/branch target (pc+imm)
--      U_src         : output std_ulogic                      - selects LUI (immediate) vs AUIPC (pc+immediate)
--      raw_src       : output std_ulogic_vector(24 downto 0)  - instruction bits with opcode (6:0) removed
--      inst_code     : output std_ulogic_vector(6 downto 0)   - instruction opcode (identifies type: R,I,S,B,U,J)
--      rs1           : output std_ulogic_vector(4 downto 0)   - source register 1
--      rs2           : output std_ulogic_vector(4 downto 0)   - source register 2
--      rd            : output std_ulogic_vector(4 downto 0)   - destination register
--      byte_en       : output std_ulogic_vector(BYTE_IN_WORD-1 downto 0) - byte lane enable for load/store
--      load_unsigned : output std_ulogic                      - selects zero-extension (LBU/LHU) vs sign-extension for loads
--
--  alu_status = (Byte select, C, Z, N, V)
--      Byte select[5:4] : Byte selected for load and store instructions
--      C [3] : Carry (ADD) / Borrow (SUB, active high when A < B unsigned)
--      Z [2] : Zero flag  (result = 0)
--      N [1] : Negative flag (MSB of result)
--      V [0] : Overflow flag (signed overflow, ADD/SUB only)
--
--  License: MIT (see LICENSE file)
--      
--
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity control_unit is 
    port (
        instruction   : in   std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        alu_status    : in   std_ulogic_vector(5 downto 0);        -- (Byte sel, C, Z, N, V)
        alu_ctrl      : out  alu_op_t;                             -- ALU operation
        alu_src       : out  std_ulogic;                           -- Manage second input of the ALU ('0' for rs2, '1' for immediate)
        PC_src        : out  pc_src_t;                             -- manage next instruction
        reg_write     : out  std_ulogic;                           -- enable write mode in register file
        mem_en_o      : out  std_ulogic;                           -- memory access enable
        mem_rw_o      : out  std_ulogic;                           -- enable read/write in data memory, 0 = read, 1 = write
        wb_src        : out  std_ulogic_vector(1 downto 0);        -- Multiplexer selecting the data written back to the register file ('00' ALU result, '01' memory read data, '10' pc + 4).
        jalr_sel      : out  std_ulogic;                           -- Multiplexer selecting the next PC address for jumps
        auipc_sel     : out  std_ulogic;                           -- Multiplexer selecting the data written back into register for U type
        raw_src       : out  std_ulogic_vector(24 downto 0);       -- Instruction once opcode (6 downto 0) is removed from it
        inst_code     : out  std_ulogic_vector(6 downto 0);        -- Give the type of instruction (R,I,S,U,J)
        rs1           : out  std_ulogic_vector(4 downto 0);        -- source register 1
        rs2           : out  std_ulogic_vector(4 downto 0);        -- source register 2
        rd            : out  std_ulogic_vector(4 downto 0);         -- destination register
        byte_en       : out std_ulogic_vector(BYTE_IN_WORD - 1 downto 0);
        load_unsigned : out std_ulogic
    );
end entity control_unit;

architecture rtl of control_unit is

    signal rs1_temp       : std_ulogic_vector(4 downto 0);
    signal rs2_temp       : std_ulogic_vector(4 downto 0);
    signal rd_temp        : std_ulogic_vector(4 downto 0);
    signal alu_op         : alu_op_t;       -- ALU operation
    signal alu_source     : std_ulogic;     -- Manage second input of the ALU ('0' for rs2, '1' for immediate)
    signal pc_source      : pc_src_t;       -- manage next instruction
    signal reg_w          : std_ulogic;     -- enable write mode in register file
    signal mem_en         : std_ulogic;     -- memory access enable
    signal mem_rw         : std_ulogic;     -- enable read/write in data memory, 0 = read, 1 = write
    signal wb_source      : std_ulogic_vector(1 downto 0);    -- Multiplexer selecting the data written back to the register file ('00' ALU result, '01' memory read data, '10' pc + 4).
    signal jalr_select    : std_ulogic;     -- Multiplexer selecting the next PC address for jumps.
    signal auipc_select   : std_ulogic;     -- Multiplexer selecting the data written back into register for U type
    signal byte_enable    : std_ulogic_vector(BYTE_IN_WORD - 1 downto 0);
    signal ld_unsigned    : std_ulogic;

begin

    proc_alu_ctrl : process(instruction)

        variable op_code : std_ulogic_vector(6 downto 0);
        variable funct3  : std_ulogic_vector(2 downto 0);
        variable funct7  : std_ulogic_vector(6 downto 0);

    begin

        alu_op     <= ALU_NOP;
        alu_source <= '0';

        op_code := instruction(6 downto 0);
        funct3  := instruction(14 downto 12);
        funct7  := instruction(31 downto 25);

        case (op_code) is

            when OPCODE_RTYPE =>

                case (funct7) is

                    when "0000000" =>

                        case (funct3) is
                            when "000" => alu_op <= ALU_ADD;
                            when "111" => alu_op <= ALU_AND;
                            when "110" => alu_op <= ALU_OR;
                            when "100" => alu_op <= ALU_XOR;
                            when "010" => alu_op <= ALU_SLT;
                            when "011" => alu_op <= ALU_SLTU;
                            when "001" => alu_op <= ALU_SLL;
                            when "101" => alu_op <= ALU_SRL;
                            when others => null;
                        end case;

                    when "0100000" =>

                        case (funct3) is
                            when "000" => alu_op <= ALU_SUB;
                            when "101" => alu_op <= ALU_SRA;
                            when others => null;
                        end case;

                    when others =>
                        null;

                end case;

            when OPCODE_ITYPE =>

                case funct3 is
                    when "000" => alu_op <= ALU_ADD;  alu_source <= '1';
                    when "010" => alu_op <= ALU_SLT;  alu_source <= '1';
                    when "011" => alu_op <= ALU_SLTU; alu_source <= '1';
                    when "100" => alu_op <= ALU_XOR;  alu_source <= '1';
                    when "110" => alu_op <= ALU_OR;   alu_source <= '1';
                    when "111" => alu_op <= ALU_AND;  alu_source <= '1';

                    when "001" => -- SLLI

                        if (funct7 = "0000000") then
                            alu_op <= ALU_SLL; 
                            alu_source <= '1';
                        end if;

                    when "101" => -- SRLI | SRAI

                        if (funct7 = "0000000") then
                            alu_op <= ALU_SRL; 
                            alu_source <= '1';
                            
                        elsif (funct7 = "0100000") then
                            alu_op <= ALU_SRA; 
                            alu_source <= '1';
                        end if;

                    when others =>
                        null;
                end case;

            when OPCODE_LOAD | OPCODE_STORE =>

                alu_op     <= ALU_ADD;
                alu_source <= '1';

            when OPCODE_BRANCH =>

                alu_op <= ALU_SUB;

            when OPCODE_JALR =>

                case (funct3) is
                    when "000" => 
                        alu_op <= ALU_ADD; 
                        alu_source <= '1';
                        
                    when others => null;
                end case;

            when others =>
                null;

        end case;

    end process proc_alu_ctrl;

    proc_comb : process(instruction, alu_status)

        variable op_code      : std_ulogic_vector(6 downto 0);
        variable funct3       : std_ulogic_vector(2 downto 0);
        variable funct7       : std_ulogic_vector(6 downto 0);
        variable byte_idx     : integer;
        variable valid        : std_ulogic := '0';
        variable status       : std_ulogic := '0';
    begin


        -- default values
        rs1_temp      <= (others => '0');
        rs2_temp      <= (others => '0');
        rd_temp       <= (others => '0');

        reg_w         <= '0';
        mem_rw        <= '0';
        mem_en        <= '0';
        wb_source     <= "00";
        jalr_select   <= '0';
        auipc_select  <= '0';
        byte_enable   <= "0000";
        ld_unsigned   <= '0';
        pc_source     <= PC_DEFAULT;

        op_code := instruction(6 downto 0);
        funct3 := instruction(14 downto 12); -- Only for R, I, S and B type
        funct7 := instruction(31 downto 25);
        byte_idx  := to_int(alu_status(5 downto 4));
        valid  := '0';

        case (op_code) is

            when OPCODE_RTYPE => -- R-type instruction

                rs1_temp <= instruction(19 downto 15);
                rs2_temp <= instruction(24 downto 20);
                rd_temp  <= instruction(11 downto 7);

                case (funct7) is

                    when "0000000" =>

                        case (funct3) is

                            when "000" | "111" | "110" | "100" | "010" | "011" | "001" | "101" =>

                                valid    := '1';

                            when others =>
                                null;

                        end case;

                    when "0100000" =>

                        case (funct3) is

                            when "000" | "101" =>

                                valid    := '1';

                            when others =>
                                null;

                        end case;

                    when others =>
                        null;

                end case;

                if (valid = '1') then

                    reg_w      <= '1';

                end if;

            when OPCODE_ITYPE  => -- I-type (immediate instruction)

                rs1_temp <= instruction(19 downto 15);
                rs2_temp <= (others => '0');
                rd_temp  <= instruction(11 downto 7);

                case funct3 is

                    when "000" | "010" | "011" | "100" | "110" | "111" =>

                        valid  := '1';

                    when "001" => -- SLLI

                        if (funct7 = "0000000") then

                            valid := '1';

                        end if;


                    when "101" => -- SRLI | SRAI

                        if (funct7 = "0000000") then

                            valid := '1';

                        elsif (funct7 = "0100000") then

                            valid := '1';

                        end if;

                    when others =>
                        null;

                end  case;

                if (valid = '1') then
                    reg_w      <= '1';

                end if;

            when OPCODE_LOAD => -- I-type (load word instruction)

                rs1_temp <= instruction(19 downto 15);
                rs2_temp <= (others => '0');
                rd_temp  <= instruction(11 downto 7);

                case (funct3) is 
                    
                    when "010" => -- LW (Load Word)

                        byte_enable <= "1111";
                        valid    := '1';

                    when "001" | "101" => -- LH (Load Half Word) & LHU (Load Half Word Unsigned)
                        
                        if (funct3 = "101") then
                            ld_unsigned <= '1';
                        end if;

                        case (byte_idx) is  
                            
                            when 0 =>

                                byte_enable <= "0011";
                                valid    := '1';

                            when 2 =>

                                byte_enable <= "1100";
                                valid    := '1';

                            when others =>
                                null;

                        end case;
                        
                    when "000" | "100" => -- LB (Load Byte) & LBU (Load Byte Unsigned)
                        
                        if (funct3 = "100") then
                            ld_unsigned <= '1';
                        end if;

                        byte_enable(byte_idx) <= '1';
                        valid    := '1';

                    when others =>
                        null;

                end case;

                if (valid = '1') then
                    reg_w       <= '1';       -- writed back in a register
                    mem_en      <= '1';
                    wb_source   <= "01";

                end if;

            when OPCODE_STORE => -- S-type (store instruction)

                rs1_temp <= instruction(19 downto 15);
                rs2_temp <= instruction(24 downto 20);

                case (funct3) is

                    when "010" =>

                        byte_enable <= "1111";
                        valid := '1';
                    
                    when "001" => -- SH (Load Half Word)

                        case (byte_idx) is  
                            
                            when 0 =>

                                byte_enable <= "0011";
                                valid    := '1';

                            when 2 =>

                                byte_enable <= "1100";
                                valid    := '1';

                            when others =>
                                null;
                                
                        end case;
                    when "000" => -- SB (Load Byte)

                        byte_enable(byte_idx)  <= '1';
                        valid    := '1';

                    when others =>
                        null;
                end case;

                if (valid = '1') then
                    mem_en     <= '1';
                    mem_rw     <= '1';

                end if;

            when OPCODE_BRANCH =>  -- B-type (branch instruction)

                rs1_temp <= instruction(19 downto 15);
                rs2_temp <= instruction(24 downto 20);

                case (funct3) is
                    
                    when "000" | "001" => -- BEQ or BNE

                        status := alu_status(2); -- Zero flag

                        if ((status = '1' and funct3 = "000") or
                            (status = '0' and funct3 = "001")) then

                            pc_source <= BRANCH;
                        
                        end if;

                    when "100" |  "101" => -- BLT or BGE
                        
                        status := alu_status(1) xor alu_status(0); -- Negative flag xor Overflow flag

                        if ((status = '1' and funct3 = "100") or
                            (status = '0' and funct3 = "101")) then

                            pc_source <= BRANCH;
                        
                        end if;
                    
                    when "110" |  "111" => -- BLTU or BGEU
                        
                        status := alu_status(3); -- Borrow

                        if ((status = '1' and funct3 = "110") or
                            (status = '0' and funct3 = "111")) then

                            pc_source <= BRANCH;
                        
                        end if;

                    when others =>
                        null;
                    
                end case;
            
            when OPCODE_JAL => -- J => -- J-type 

                rs1_temp <= (others => '0');
                rs2_temp <= (others => '0');
                rd_temp  <= instruction(11 downto 7);
        
                wb_source   <= "10";
                reg_w      <= '1';
                pc_source   <= JUMP;
                jalr_select <= '0';

            when OPCODE_JALR  => -- I-type (Jump and link register instruction)

                rs1_temp <= instruction(19 downto 15);
                rs2_temp <= (others => '0');
                rd_temp  <= instruction(11 downto 7);
                
                case (funct3) is 
                    
                    when "000" => -- JALR (Jump And Link Register)

                        reg_w      <= '1';       -- writed back in a register
                        wb_source  <= "10";
                        jalr_select <= '1';
                        pc_source   <= JUMP;

                    when others =>
                        null;

                end case;
            
            when OPCODE_LUI => -- U-type (LUI instruction)
                
                rd_temp       <= instruction(11 downto 7);
                auipc_select  <= '0';
                wb_source     <= "11";
                reg_w         <= '1';    
            
            when OPCODE_AUIPC => -- U-type (AUIPC instruction)
                
                rd_temp       <= instruction(11 downto 7);
                auipc_select  <= '1';
                wb_source     <= "11";
                reg_w         <= '1';    

            when others =>
                null;

        end case;
    
    end process proc_comb;

    inst_code     <= instruction(6 downto 0);
    raw_src       <= instruction(DATA_WIDTH -1 downto 7); 
    rs1           <= rs1_temp;
    rs2           <= rs2_temp;
    rd            <= rd_temp;
    alu_ctrl      <= alu_op;
    alu_src       <= alu_source;
    PC_src        <= pc_source;
    reg_write     <= reg_w;
    mem_rw_o      <= mem_rw;
    mem_en_o      <= mem_en;
    wb_src        <= wb_source;
    jalr_sel      <= jalr_select;
    auipc_sel     <= auipc_select;
    byte_en       <= byte_enable;
    load_unsigned <= ld_unsigned;

end architecture rtl;