--==============================================================================
--  Module      : ALU_dut_wrapper
--  Purpose     : SystemVerilog-facing adapter for the ALU testbench.
--                ModelSim/Questa cannot connect a VHDL enumerated port
--                (alu_op_t) directly to a SystemVerilog module (vsim-3362).
--                This wrapper exposes a plain std_ulogic_vector ALU_ctrl port,
--                converts it to alu_op_t by position, and instantiates the
--                real ALU used by the rest of the design.
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity ALU_dut_wrapper is
    port(
        ALU_ctrl    : in  std_ulogic_vector(3 downto 0);
        A           : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
        B           : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
        Status_out  : out std_ulogic_vector(3 downto 0);
        Y           : out std_ulogic_vector(DATA_WIDTH-1 downto 0)
    );
end entity ALU_dut_wrapper;

architecture rtl of ALU_dut_wrapper is
    signal ctrl_enum : alu_op_t;
begin

    ctrl_enum <= alu_op_t'val(to_integer(unsigned(ALU_ctrl)));

    dut : entity work.ALU
        port map(
            ALU_ctrl   => ctrl_enum,
            A          => A,
            B          => B,
            Status_out => Status_out,
            Y          => Y
        );

end architecture rtl;
