--==============================================================================
--  Module      : Arithmetic Logic Unit (ALU)
--  File        : ALU.vhd
--  Description : ALU module performing arithmetic and logical operations.
--                Each operation is computed combinationally and the result is
--                provided to the control unit.
--
--  Author      : Olivier Oribes
--  Created     : 2026-03-10
--  Last update : 2026-04-03
--
--  Version     : 1.1
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
--      Status_out  : out std_ulogic_vector(3 downto 0)            -- status output
--
--  Status_out = (C, Z, N, V)
--      C [3] : Carry (ADD) / Borrow (SUB, active high when A < B unsigned)
--      Z [2] : Zero flag  (result = 0)
--      N [1] : Negative flag (MSB of result)
--      V [0] : Overflow flag (signed overflow, ADD/SUB only)
--
--  ALU_ctrl encoding:
--      0000 : AND
--      0001 : OR
--      0010 : ADD
--      0011 : XOR
--      0110 : SUB
--      0111 : SLT  (Set on Less Than, signed)
--      1101 : SLL  (Shift Left Logical by 1, carry = evicted MSB)
--      1110 : SRL  (Shift Right Logical by 1, carry = evicted LSB)
--      others : result = 0, all flags = 0
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
        A           : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
        B           : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
        Status_out  : out std_ulogic_vector(3 downto 0); -- (C, Z, N, V)
        Y           : out std_ulogic_vector(DATA_WIDTH-1 downto 0)
    );
end entity ALU;


architecture rtl of ALU is
begin

    process(A, B, ALU_ctrl)
        -- Index DATA_WIDTH   = bit de carry/borrow (bit 32 pour DATA_WIDTH=32)
        -- Index DATA_WIDTH-1 = MSB du résultat utile (bit 31)
        -- Index 0            = LSB
        variable result  : std_ulogic_vector(DATA_WIDTH downto 0);
        variable carry   : std_ulogic;   -- carry/borrow à loger dans Status_out(3)
    begin

        carry := '0';

        case ALU_ctrl is

            -- Logical operations (carry bit forced to 0 via '0' & ...)
            when ALU_AND => result := '0' & (A and B);
            when ALU_OR => result := '0' & (A or  B);
            when ALU_XOR => result := '0' & (A xor B);

            -- ADD : unsigned extended addition to capture carry out
            when ALU_ADD =>
                result := std_ulogic_vector(unsigned('0' & A) + unsigned('0' & B));

            -- SUB : unsigned extended subtraction.
            -- Convention : C=1 means borrow (A < B unsigned), i.e. C = NOT result(DATA_WIDTH)
            when ALU_SUB =>
                result := std_ulogic_vector(unsigned('0' & A) - unsigned('0' & B));

            -- SLT : signed comparison, result = 1 if A < B (signed), else 0
            when ALU_SLT =>
                result := (others => '0');
                if signed(A) < signed(B) then
                    result(0) := '1';
                end if;

            -- SLL : shift left logical by 1.
            when ALU_SLL =>
                result := '0' & std_ulogic_vector(shift_left(unsigned(A), 1));

            -- SRL : shift right logical by 1.
            when ALU_SRL =>
                result := '0' & std_ulogic_vector(shift_right(unsigned(A), 1));

            when others =>
                result := (others => '0');

        end case;

        -- -------------------------------------------------------
        -- Output : DATA_WIDTH useful bits
        -- -------------------------------------------------------
        Y <= result(DATA_WIDTH-1 downto 0);

        -- -------------------------------------------------------
        -- Status flags
        -- -------------------------------------------------------

        -- C [3] : Carry / Borrow
        --   ADD      : carry out = result(DATA_WIDTH)
        --   SUB      : borrow    = NOT result(DATA_WIDTH)  (A-B underflows when bit=1)
        --   SHL/SHR  : evicted bit captured in variable carry
        --   others   : 0
        case ALU_ctrl is
            when ALU_ADD =>                        
                Status_out(3) <= result(DATA_WIDTH);
            when ALU_SUB => 
                if unsigned(A) < unsigned(B) then
                    Status_out(3) <= '1'; -- borrow
                else
                    Status_out(3) <= '0';
                end if;
            when ALU_SRL | ALU_SLL =>                 
                Status_out(3) <= carry;
            when others =>
                Status_out(3) <= '0';
        end case;

        -- Z [2] : Zero flag
        if unsigned(result(DATA_WIDTH-1 downto 0)) = 0 then
            Status_out(2) <= '1';
        else
            Status_out(2) <= '0';
        end if;

        -- N [1] : Negative flag (MSB of useful result)
        Status_out(1) <= result(DATA_WIDTH-1);

        -- V [0] : Overflow flag (signed overflow, ADD and SUB only)
        --   ADD : overflow when two same-sign operands give opposite-sign result
        --   SUB : overflow when A and B have opposite signs and result sign ≠ A sign
        case ALU_ctrl is
            when ALU_ADD => 
                Status_out(0) <=
                    (    A(DATA_WIDTH-1) and     B(DATA_WIDTH-1) and not result(DATA_WIDTH-1)) or
                    (not A(DATA_WIDTH-1) and not B(DATA_WIDTH-1) and     result(DATA_WIDTH-1));

            when ALU_SUB => 
                Status_out(0) <=
                    (    A(DATA_WIDTH-1) and not B(DATA_WIDTH-1) and not result(DATA_WIDTH-1)) or
                    (not A(DATA_WIDTH-1) and     B(DATA_WIDTH-1) and     result(DATA_WIDTH-1));

            when others =>
                Status_out(0) <= '0';
        end case;

    end process;

end architecture rtl;