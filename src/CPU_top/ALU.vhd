--==============================================================================
--  Module      : Arithmetic Logic Unit (ALU)
--  File        : ALU.vhd
--  Description : ALU module performing arithmetic and logical operations.
--                Each operation is computed combinationally and the result is
--                provided to the control unit.
--
--  Author      : Olivier Oribes
--  Created     : 2026-03-10
--  Last update : 2026-09-02
--
--  Version     : 1.2
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--  Dependencies:
--      - work.cpu_pkg (DATA_WIDTH definition)
--
--  Generics:
--      DATA_WIDTH : integer := 32   -- Data width (in bits)
--
--  Ports:
--      ALU_ctrl : in  std_ulogic_vector(3 downto 0)            -- operation code
--      A           : in  std_ulogic_vector(DATA_WIDTH-1 downto 0) -- operand 1
--      B           : in  std_ulogic_vector(DATA_WIDTH-1 downto 0) -- operand 2
--      Y           : out std_ulogic_vector(DATA_WIDTH-1 downto 0) -- result
--      status_out  : out std_ulogic_vector(3 downto 0)            -- status output
--
--  status_out = (Byte select, C, Z, N, V)  
--      Byte select[5:4] : Byte selected for Load and store instruction
--      C [3] : Carry (ADD) / Borrow (SUB, active high when A < B unsigned)
--      Z [2] : Zero flag  (result = 0)
--      N [1] : Negative flag (MSB of result)
--      V [0] : Overflow flag (signed overflow, ADD/SUB only)
--
--
--  License: MIT (see LICENSE file)
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;


entity ALU is
    port(
        ALU_ctrl    : in  alu_op_t;
        A           : in  std_ulogic_vector(DATA_WIDTH-1 downto 0); -- rs1_data
        B           : in  std_ulogic_vector(DATA_WIDTH-1 downto 0); -- rs2_data or immediate
        status_out  : out std_ulogic_vector(5 downto 0); -- (Byte select, C, Z, N, V)
        Y           : out std_ulogic_vector(DATA_WIDTH-1 downto 0) -- Result of the operation
    );
end entity ALU;


architecture rtl of ALU is
begin

    process(A, B, ALU_ctrl)
        -- Index DATA_WIDTH   = bit de carry/borrow (bit 32 pour DATA_WIDTH=32)
        -- Index DATA_WIDTH-1 = MSB du résultat utile (bit 31)
        -- Index 0            = LSB
        variable result  : std_ulogic_vector(DATA_WIDTH downto 0);
        variable shamt   : natural range 0 to DATA_WIDTH;
    begin


        -- RV32I shift amount: only the 5 least-significant bits are used
        shamt := to_integer(unsigned(B(4 downto 0)));
        status_out(0) <= '0';
        status_out(3) <= '0';
        status_out(5 downto 4) <= "00"; 

        case ALU_ctrl is

            -- Logical operations (carry bit forced to 0 via '0' & ...)
            when ALU_AND => result := '0' & (A and B);
            when ALU_OR => result := '0' & (A or  B);
            when ALU_XOR => result := '0' & (A xor B);

            -- ADD : unsigned extended addition to capture carry out
            when ALU_ADD =>
                result := std_ulogic_vector(unsigned('0' & A) + unsigned('0' & B));

                -- C [3] : Carry / Borrow
                --   ADD      : carry out = result(DATA_WIDTH)
                status_out(3) <= result(DATA_WIDTH);

                -- V [0] : Overflow flag (signed overflow, ADD and SUB only)
                --   ADD : overflow when two same-sign operands give opposite-sign result
                status_out(0) <=
                    (    A(DATA_WIDTH-1) and     B(DATA_WIDTH-1) and not result(DATA_WIDTH-1)) or -- negative + negative equal positive 
                    (not A(DATA_WIDTH-1) and not B(DATA_WIDTH-1) and     result(DATA_WIDTH-1));   -- positive + positive equal negative

                -- Byte selection within a word for Load and Store instructions
                status_out(5 downto 4) <= result(1 downto 0);


            -- SUB : unsigned extended subtraction.
            -- Convention : C=1 means borrow (A < B unsigned), i.e. C = NOT result(DATA_WIDTH)
            when ALU_SUB =>
                result := std_ulogic_vector(unsigned('0' & A) - unsigned('0' & B));

                -- C [3] : Carry / Borrow
                --   SUB      : borrow    = NOT result(DATA_WIDTH)  (A-B underflows when bit=1)
                if unsigned(A) < unsigned(B) then
                    status_out(3) <= '1'; -- borrow
                else
                    status_out(3) <= '0';
                end if;

                -- V [0] : Overflow flag (signed overflow, ADD and SUB only)
                --   SUB : overflow when A and B have opposite signs and result sign ≠ A sign
                status_out(0) <=
                    (    A(DATA_WIDTH-1) and not B(DATA_WIDTH-1) and not result(DATA_WIDTH-1)) or -- negative - positive equal positive 
                    (not A(DATA_WIDTH-1) and     B(DATA_WIDTH-1) and     result(DATA_WIDTH-1));   -- positive - negative equal negative


            -- SLT : signed comparison, result = 1 if A < B (signed), else 0
            when ALU_SLT =>
                result := (others => '0');
                if signed(A) < signed(B) then
                    result(0) := '1';
                end if;

            -- SLTU : unsigned comparison, result = 1 if A < B (unsigned), else 0
            when ALU_SLTU =>
                result := (others => '0');
                if unsigned(A) < unsigned(B) then
                    result(0) := '1';
                end if;

            -- SLL : shift left logical by B.
            when ALU_SLL =>
                result := '0' & std_ulogic_vector(shift_left(unsigned(A), shamt));

            -- SRL : shift right logical by B.
            when ALU_SRL =>
                result := '0' & std_ulogic_vector(shift_right(unsigned(A), shamt));

            -- SRA : shift right arithmetic by B.

            when ALU_SRA =>
                result := '0' & std_ulogic_vector(shift_right(signed(A), shamt));

            when others =>
                result := (others => '0');

        end case;
        
        -- N [1] : Negative flag (MSB of useful result)
        status_out(1) <= result(DATA_WIDTH-1);

        -- Z [2] : Zero flag
        if unsigned(result(DATA_WIDTH-1 downto 0)) = 0 then
            status_out(2) <= '1';
        else
            status_out(2) <= '0';
        end if;

        -- -------------------------------------------------------
        -- Output : DATA_WIDTH useful bits
        -- -------------------------------------------------------
        Y <= result(DATA_WIDTH-1 downto 0);

    end process;

end architecture rtl;