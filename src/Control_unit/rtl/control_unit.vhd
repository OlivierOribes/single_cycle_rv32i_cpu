--==============================================================================
--  Module      : Control unit
--  File        : control_unit.vhd
--  Description : Decodes the current instruction and generates the control
--                signals used by the datapath (ALU opcode, immediate/register
--                ALU source select, register-file write enable) along with
--                the extracted instruction fields (opcode, funct fields,
--                register indexes).
--
--
--  Author      : Olivier Oribes
--  Created     : 17/07/2026
--  Last update : 20/07/2026
--
--  Version     : 1.1
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
--      ALU_ctrl    : output std_ulogic_vector[3:0]          - 4-bit ALU opcode
--      ALU_src     : output std_ulogic                      - selects register (0) or immediate (1) as ALU source
--      reg_write   : output std_ulogic                      - write enable for register file module
--      mem_en_o    : output std_ulogic                      - memory access enable
--      mem_rw_o    : output std_ulogic                      - read/write select for data memory (0 = read, 1 = write)
--      mem_to_reg  : output std_ulogic                      - selects write-back data (0 = ALU result, 1 = memory read data)
--      raw_src     : output std_logic_vector[24:0]          - instruction bits with opcode (6:0) removed
--      inst_code   : output std_logic_vector[6:0]           - instruction opcode (identifies type: R,I,S,U,J)
--      rs1         : output std_logic_vector[4:0]           - source register 1
--      rs2         : output std_logic_vector[4:0]           - source register 2
--      rd          : output std_logic_vector[4:0]           - destination register
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
        instruction : in   std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        ALU_ctrl    : out  std_ulogic_vector(3 downto 0);        -- ALU opcode
        ALU_src     : out  std_ulogic;                           -- enable or disable immediate using MUX
        reg_write   : out  std_ulogic;                           -- enable write mode in register file
        mem_en_o    : out  std_ulogic;                           -- memory access enable
        mem_rw_o    : out  std_ulogic;                           -- enable read/write in data memory, 0 = read, 1 = write
        mem_to_reg  : out  std_ulogic;                         -- Multiplexer selecting the data written back to the register file (ALU result or memory read data).
        raw_src     : out  std_ulogic_vector(24 downto 0);       -- Instruction once opcode (6 downto 0) is removed from it
        inst_code   : out  std_ulogic_vector(6 downto 0);        -- Give the type of instruction (R,I,S,U,J)
        rs1         : out  std_ulogic_vector(4 downto 0);        -- source register 1
        rs2         : out  std_ulogic_vector(4 downto 0);        -- source register 2
        rd          : out  std_ulogic_vector(4 downto 0)         -- destination register
    );
end entity control_unit;

architecture rtl of control_unit is

    signal rs1_temp       : std_ulogic_vector(4 downto 0);
    signal rs2_temp       : std_ulogic_vector(4 downto 0);
    signal rd_temp        : std_ulogic_vector(4 downto 0);
    signal ALU_op         : std_ulogic_vector(3 downto 0);
    signal ALU_source     : std_ulogic;
    signal reg_w          : std_ulogic;
    signal mem_en         : std_ulogic;
    signal mem_rw         : std_ulogic;
    signal mux_op         : std_ulogic;

begin

    proc_comb : process(instruction)

        variable op_code : std_ulogic_vector(6 downto 0);
        variable funct3  : std_ulogic_vector(2 downto 0);
        variable funct7  : std_ulogic_vector(6 downto 0);
        variable valid   : std_ulogic := '0';
    begin


        -- default values
        rs1_temp      <= (others => '0');
        rs2_temp      <= (others => '0');
        rd_temp       <= (others => '0');

        ALU_op        <= "0000";
        ALU_source    <= '0';
        reg_w         <= '0';
        mem_rw        <= '0'; 
        mem_en        <= '0';
        mux_op        <= '0';

        op_code := instruction(6 downto 0);
        funct3 := instruction(14 downto 12); -- Only for R, I, S and B type
        funct7 := instruction(31 downto 25);
        valid  := '0';
        
        case (op_code) is
            
            when "0110011" => -- R-type instruction

                rs1_temp <= instruction(19 downto 15);
                rs2_temp <= instruction(24 downto 20);
                rd_temp  <= instruction(11 downto 7);

                case (funct7) is

                    when "0000000" =>

                        case (funct3) is

                            when "000" => -- ADD operation

                                ALU_op     <= "0010";
                                valid    := '1';

                            when "111" => -- AND operation

                                ALU_op     <= "0000";
                                valid    := '1';

                            when "110" => -- OR operation

                                ALU_op     <= "0001";
                                valid    := '1';
                            
                            when "100" => -- XOR operation

                                ALU_op     <= "0011";
                                valid    := '1';

                            when "010" => -- SLT  (Set on Less Than, signed)

                                ALU_op     <= "0111";
                                valid    := '1';

                            when "001" => -- SLL  (Shift Left Logical by 1, carry = evicted MSB)

                                ALU_op     <= "1101";
                                valid    := '1';

                            when "101" => -- SRL  (Shift Right Logical by 1, carry = evicted MSB)

                                ALU_op     <= "1110";
                                valid    := '1';

                            when others =>
                                null;

                        end case;
                        
                    when "0100000" =>

                        case (funct3) is 

                            when "000" => -- SUB operation

                                ALU_op     <= "0110";
                                valid    := '1';
                            when others =>
                                null;

                        end case;
                    
                    when others =>
                        null;

                end case;
                
                if (valid = '1') then 
                    ALU_source <= '0';
                    reg_w   <= '1';  
                    mux_op  <= '0'; -- ALU result is the data written back to the register file
                
                end if;

            when "0000011"  => -- I-type (load instruction)

                rs1_temp <= instruction(19 downto 15);
                rs2_temp <= (others => '0');
                rd_temp  <= instruction(11 downto 7);
                
                case (funct3) is 

                    when "010" => -- LW (Load Word)

                        ALU_op     <= "0010"; -- ADD operation
                        valid    := '1';
                    when others =>
                        null;

                end case;

                if (valid = '1') then 
                    ALU_source <= '1';    -- second operand (immediate)
                    reg_w   <= '1';       -- writed back in a register
                    mem_en  <= '1';
                    mux_op  <= '1';       -- data read from memory is written back to the register file
                end if;

            when others =>
                null;

        end case;
    
    end process proc_comb;

    inst_code <= instruction(6 downto 0);
    raw_src   <= instruction(DATA_WIDTH -1 downto 7); 
    rs1 <= rs1_temp;
    rs2 <= rs2_temp;
    rd  <= rd_temp;
    ALU_ctrl <= ALU_op    ;
    ALU_src  <= ALU_source;
    reg_write <= reg_w;
    mem_rw_o <= mem_rw;
    mem_en_o <= mem_en;
    mem_to_reg <= mux_op;


end architecture rtl;