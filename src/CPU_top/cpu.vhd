--==============================================================================
--  Module      : CPU
--  File        : cpu.vhd
--  Description : Top-level single-cycle RISC-V CPU. Wires together the
--                program counter, instruction memory, register file,
--                control unit, ALU, data memory, sign extender and
--                write-back muxes into a complete datapath.
--
--                Currently supported instructions: R-type (ADD, SUB, AND,
--                OR, XOR, SLT, SLL, SRL) and I-type LOAD (LW). Branches,
--                jumps and STORE are not yet implemented.
--
--  Author      : Olivier Oribes
--  Created     : 20/07/2026
--  Last update : 24/07/2026
--
--  Version     : 1.0
--
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--
--  Dependencies:
--      - cpu_pkg.vhd
--
--
--  Ports:
--      clk    : in std_ulogic - system clock
--      rst_n  : in std_ulogic - asynchronous active-low reset
--
--  License     : MIT (see LICENSE file)
--==============================================================================

library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;


entity cpu is port
    (
        clk          : in std_ulogic;
        rst_n        : in std_ulogic := '1'; -- asynchronous active-low reset
        
        
        -- Debut signals
        rs1_o       : out std_ulogic_vector(4 downto 0);
        rs1_data_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        rd_o        : out std_ulogic_vector(4 downto 0);
        imm         : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        alu_res_o   : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        rf_wd       : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        pc_reg      : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
        instruction : out std_ulogic_vector(DATA_WIDTH-1 downto 0)

    );
end entity cpu;

architecture rtl of cpu is

    constant ZERO       : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

    -- Program counter signals
    signal load         : std_ulogic := '0';
    signal pc_out       : std_ulogic_vector(DATA_WIDTH-1 downto 0);
    
    -- Instruction memory signals
    -- signal inst_en_i    : std_ulogic;                                 -- memory access enable
    -- signal inst_rw_i    : std_ulogic;                                 -- 0 = read, 1 = write
    -- signal inst_data_i  : std_ulogic_vector(DATA_WIDTH-1 downto 0);   -- data to write in memory
    signal inst_data_o  : std_ulogic_vector(DATA_WIDTH-1 downto 0);      -- memory data out

    -- Data memory signals
    signal dat_data_o     : std_ulogic_vector(DATA_WIDTH-1 downto 0);                       -- memory data out
    -- Sign extender signals
    signal raw_src        :  std_ulogic_vector(24 downto 0);                                -- Instruction once opcode (6 downto 0) is removed from it
    signal inst_code      :  std_ulogic_vector(6 downto 0);                                 -- Give the type of instruction (R,I,S,U,J)
    signal immediate      :  std_ulogic_vector(ADDR_WIDTH-1 downto 0); 

    -- ALU signals
    signal ALU_ctrl       : alu_op_t;
    signal rs1            : std_ulogic_vector(4 downto 0);
    signal rs2            : std_ulogic_vector(4 downto 0);
    signal rs1_data       : std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal rs2_data       : std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal alu_status     : std_ulogic_vector(3 downto 0); -- (C, Z, N, V)
    signal alu_res        : std_ulogic_vector(DATA_WIDTH-1 downto 0);

    -- Control unit signals
    signal ALU_src     :  std_ulogic;                           -- enable or disable immediate using MUX
    signal rf_write    :  std_ulogic;                           -- enable write mode in register file
    signal mem_en_o    :  std_ulogic;                           -- memory access enable
    signal mem_rw_o    :  std_ulogic;                           -- enable read/write in data memory, 0 = read, 1 = write
    signal mem_to_reg  :  std_ulogic;                           -- Multiplexer selecting the data written back to the register file (ALU result or memory read data).
    signal rd          :  std_ulogic_vector(4 downto 0) ;       -- destination register

    signal rf_mux_o    : std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- output of the mux that take rs2 and immediate in input
    signal rf_wdata    : std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- data that will be write back to register file

begin

     
    -- Instance of program_counter for simulation
    program_counter_inst : entity work.program_counter
    port map(
        clk    => clk,
        rst_n  => rst_n,
        load   => load,
        pc_in  => pc_out,
        pc_out => pc_out
    );


    instruction_memory_inst : entity work.imem
    generic map(
        FILENAME => "program.hex"
    )
    port map(
        clk    => clk,
        rst_n  => '1',
        en_i   => '1',
        rw_i   => '0',
        addr_i => pc_out,
        data_i => ZERO,
        data_o => inst_data_o
    );

    register_file_inst : entity work.register_file
    port map (
        clk          => clk,
        rst_n        => rst_n,
        write_enable => rf_write,
        rs1_i        => rs1,
        rs2_i        => rs2,
        rd           => rd,
        write_data   => rf_wdata,
        rs1_data_o   => rs1_data,
        rs2_data_o   => rs2_data
    );


    control_unit_inst : entity work.control_unit
    port map (
        instruction => inst_data_o,
        ALU_ctrl    => ALU_ctrl,
        ALU_src     => ALU_src,
        reg_write   => rf_write,
        mem_en_o    => mem_en_o,
        mem_rw_o    => mem_rw_o,
        mem_to_reg  => mem_to_reg,
        raw_src     => raw_src,
        inst_code   => inst_code,
        rs1         => rs1,
        rs2         => rs2,
        rd          => rd
    );

    alu_inst : entity work.ALU 
    port map(
        ALU_ctrl    => ALU_ctrl,
        A           => rs1_data,
        B           => rf_mux_o,
        status_out  => alu_status,
        Y           => alu_res
    );

    data_memory_inst : entity work.dmem
    generic map(
        FILENAME => "dmem_init.hex"
    )
    port map(
        clk    => clk,
        rst_n  => '1',
        en_i   => mem_en_o,
        rw_i   => mem_rw_o,
        addr_i => alu_res,
        data_i => rs2_data,
        data_o => dat_data_o
    );


    sign_extender_inst : entity work.sign_extender
    port map(
            raw_src     => raw_src,
            inst_code   => inst_code,
            immediate   => immediate
    );

    rf_output_mux : entity work.mux 
    port map(
        data_i1 => rs2_data,
        data_i2 => immediate,
        op      => ALU_src,
        data_o  => rf_mux_o
    );

    data_to_register_mux : entity work.mux 
    port map(
        data_i1 => alu_res,
        data_i2 => dat_data_o,
        op      => mem_to_reg,
        data_o  => rf_wdata
    );

    -- Debug signals assignment 
    rs1_o       <= rs1;         
    rd_o        <= rd;          -- Address of the register where rf_wdata will be writed back
    imm         <= immediate;  
    alu_res_o   <= alu_res;     -- ALU output (address of the data in the dmem)
    rf_wd       <= rf_wdata;    -- data writed back to register
    pc_reg      <= pc_out;      -- Address of the next instruction in the imem
    instruction <= inst_data_o; -- Instruction from imem
    rs1_data_o  <= rs1_data;    -- Containt of register at the address

end architecture rtl;