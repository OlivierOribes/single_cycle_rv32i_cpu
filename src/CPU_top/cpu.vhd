--==============================================================================
--  Module      : CPU
--  File        : cpu.vhd
--  Description : Top-level single-cycle RISC-V CPU. Wires together the
--                program counter, instruction memory, register file,
--                control unit, ALU, data memory, sign extender and
--                write-back muxes into a complete datapath.
--
--                Currently supported instructions: R-type (ADD, SUB, AND,
--                OR, XOR, SLT, SLTU, SLL, SRL, SRA), I-type ALU (ADDI, SLTI,
--                SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI), LW, SW, all
--                branches (BEQ, BNE, BLT, BGE, BLTU, BGEU), JAL, JALR, LUI
--                and AUIPC. LB, LH, LBU, LHU, SB and SH are not yet
--                implemented (data memory only supports full-word accesses).
--
--  Author      : Olivier Oribes
--  Created     : 20/07/2026
--  Last update : 02/09/2026
--
--  Version     : 1.1
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
        clk_i        : in  std_ulogic;
        btn0         : in  std_ulogic := '1'; -- asynchronous active-low reset
        
        -- Hardware port
        -- GPIO --
        gpio_o       : out std_ulogic_vector(6 downto 0) --  LED

        -- UART0 --
        -- uart0_rxd_i  : in  std_ulogic;  -- UART receive data
        -- uart0_txd_o  : out std_ulogic;  -- UART send data
        

        -- Debut simulation signals
        -- rs1_o        : out std_ulogic_vector(4 downto 0);
        -- rs1_data_o   : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        -- rs2_o        : out std_ulogic_vector(4 downto 0);
        -- rs2_data_o   : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        -- rd_o         : out std_ulogic_vector(4 downto 0);
        -- imm          : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        -- alu_res_o    : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        -- rf_wd        : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        -- pc_out       : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
        -- instruction  : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
        -- pc_source    : out pc_src_t;          
        -- alu_status_o : out std_ulogic_vector(5 downto 0) -- (Byte select, C, Z, N, V)
    );
end entity cpu;

architecture rtl of cpu is

    signal clk             : std_ulogic;

    -- Harware signal 
    signal gpio_reg        : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal gpio_addr_match : std_ulogic;
    signal rst_n           : std_ulogic;

    -- Program counter signals
    signal pc_next         : std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Next address in the pc counter
    signal pc_current      : std_ulogic_vector(DATA_WIDTH - 1 downto 0);

    -- Instruction memory signals
    -- signal imem_en_i    : std_ulogic;                                 -- memory access enable
    -- signal imem_rw_i    : std_ulogic;                                 -- 0 = read, 1 = write
    -- signal imem_data_i  : std_ulogic_vector(DATA_WIDTH-1 downto 0);   -- data to write in memory
    signal imem_data_o   : std_ulogic_vector(DATA_WIDTH-1 downto 0);      -- memory data out

    -- Data memory signals
    signal dem_data_o     : std_ulogic_vector(DATA_WIDTH-1 downto 0);                       -- memory data out
    signal byte_en        : std_ulogic_vector(BYTE_IN_WORD - 1 downto 0);                   -- byte-write enable
    -- Sign extender signals
    signal raw_src        :  std_ulogic_vector(24 downto 0);                                -- Instruction once opcode (6 downto 0) is removed from it
    signal inst_code      :  std_ulogic_vector(6 downto 0);                                 -- Give the type of instruction (R,I,S,U,J)
    signal immediate      :  std_ulogic_vector(ADDR_WIDTH-1 downto 0);

    -- ALU signals
    signal alu_ctrl       : alu_op_t;
    signal rs1            : std_ulogic_vector(4 downto 0);
    signal rs2            : std_ulogic_vector(4 downto 0);
    signal rs1_data       : std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal rs2_data       : std_ulogic_vector(DATA_WIDTH-1 downto 0);
    signal alu_status     : std_ulogic_vector(5 downto 0); -- (Byte select, C, Z, N, V)
    signal alu_res        : std_ulogic_vector(DATA_WIDTH-1 downto 0);

    -- Control unit signals
    signal alu_src_o   :  std_ulogic;                           -- enable or disable immediate using MUX
    signal pc_src_o    :  pc_src_t;                             -- manage next instruction
    signal rf_write    :  std_ulogic;                           -- enable write mode in register file
    signal mem_en_o    :  std_ulogic;                           -- memory access enable
    signal mem_rw_o    :  std_ulogic;                           -- enable read/write in data memory, 0 = read, 1 = write
    signal wb_src      :  std_ulogic_vector(1 downto 0);        -- Multiplexer selecting the data written back to the register file (ALU result, memory read data, pc + 4).
    signal jalr_sel    :  std_ulogic;                           -- Multiplexer selecting the next address for the jump instruction
    signal auipc_sel   :  std_ulogic;                           -- Multiplexer selecting the data written back into register
    signal rd          :  std_ulogic_vector(4 downto 0) ;       -- destination register
    signal alu_b_data  :  std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- output of the mux that take rs2 and immediate in input
    signal rf_wdata    :  std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- data that will be write back to register file
    signal ld_unsigned :  std_ulogic;                            -- load unsigned
    signal load_data   :  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal return_addr :  std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Return address for jalr and jal instructions
    signal jump_addr   :  std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Jump address for jal, jalr, AUIPC, LUI and branch instructions


    attribute dont_touch : string;
    attribute dont_touch of gpio_addr_match : signal is "true";

begin

    rst_n <= not btn0;

    -- Clock divider based on a configurable ratio.
    wizard_clock_inst : entity work.wizard_clock
    port map(
        clk_i => clk_i,
        clk_o => clk,
        rst_n => rst_n
    );

    -- Instance of program_counter

    proc_ff: process(clk, rst_n)
    begin 

        if rst_n = '0' then  -- Asynchronous negedge reset

            pc_current <= (others => '0');
    
        elsif rising_edge(clk) then

            pc_current <= pc_next; 

        end if;
        
    end process proc_ff;
    
    instruction_memory_inst : entity work.imem
    generic map(
        FILENAME => "/home/olivier/Documents/Workspace/Projet_Single_CPU_VHDL/Program/test_blink_led/program.hex"
    )
    port map(
        addr_i => pc_current,
        data_o => imem_data_o 
    );

    register_file_inst : entity work.register_file
    port map (
        clk          => clk,
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
        instruction   => imem_data_o ,
        alu_status    => alu_status,
        alu_ctrl      => alu_ctrl,
        alu_src       => alu_src_o,
        pc_src        => pc_src_o,
        byte_en       => byte_en,
        load_unsigned => ld_unsigned,
        jalr_sel      => jalr_sel,
        auipc_sel     => auipc_sel,
        reg_write     => rf_write,
        mem_en_o      => mem_en_o,
        mem_rw_o      => mem_rw_o,
        wb_src        => wb_src,
        raw_src       => raw_src,
        inst_code     => inst_code,
        rs1           => rs1,
        rs2           => rs2,
        rd            => rd
    );

    alu_inst : entity work.ALU 
    port map(
        alu_ctrl    => alu_ctrl,
        A           => rs1_data,
        B           => alu_b_data,
        status_out  => alu_status,
        Y           => alu_res
    );

    data_memory_inst : entity work.dmem
    generic map(
        FILENAME => "/home/olivier/Documents/Workspace/Projet_Single_CPU_VHDL/dmem_init/dmem_init.hex"
    )
    port map(
        clk     => clk,
        en_i    => mem_en_o,
        byte_en => byte_en,
        rw_i    => mem_rw_o,
        addr_i  => alu_res,
        data_i  => rs2_data,
        data_o  => dem_data_o
    );
    
    sign_extender_inst : entity work.sign_extender
    port map(
            raw_src     => raw_src,
            inst_code   => inst_code,
            immediate   => immediate
    );
    
    -- Process for load half word and load byte
    proc_comb: process(dem_data_o, byte_en, ld_unsigned)
        
        variable sign_bit : std_ulogic;
        variable k        : integer;

    begin

        k := 0;
        sign_bit := '0';
        load_data <= (others => '0');

        for s in 0 to BYTE_IN_WORD - 1 loop

            if (byte_en(s) = '1') then
                sign_bit := dem_data_o((s+1)*BYTE_WIDTH - 1);
            end if;

        end loop;
        
        for b in 0 to BYTE_IN_WORD - 1 loop

            if (byte_en(b) = '1') then

                load_data((k+1)*BYTE_WIDTH - 1 downto k*BYTE_WIDTH) <= dem_data_o((b+1)*BYTE_WIDTH - 1 downto b*BYTE_WIDTH);
                k := k + 1;
            end if;
    
        end loop; 
        
        if (ld_unsigned = '0') then

            load_data(DATA_WIDTH - 1 downto  k*BYTE_WIDTH) <= (others => sign_bit);

        else
        
            load_data(DATA_WIDTH - 1 downto k*BYTE_WIDTH) <= (others => '0');

        end if;

    end process proc_comb;
    

    gpio_addr_match <= '1' when (alu_res = GPIO_LED_ADDR) else '0';

    proc_gpio : process(clk, rst_n)

    begin

        if (rst_n = '0') then

            gpio_reg <= (others => '0');

        elsif rising_edge(clk) then 

            if ((mem_en_o = '1') and (mem_rw_o = '1') and (gpio_addr_match = '1')) then

                gpio_reg <= rs2_data;

            end if;
        
        end if;

    end process proc_gpio;

    return_addr <= std_ulogic_vector(unsigned(pc_current) + 4);
    jump_addr   <= std_ulogic_vector(unsigned(pc_current) + unsigned(immediate));

    alu_b_data  <= rs2_data when (alu_src_o = '0') else
                   immediate when (alu_src_o = '1') else
                   (others => '0');

    rf_wdata    <= alu_res when (wb_src = "00") else
                   load_data when (wb_src = "01") else
                   return_addr when (wb_src = "10") else
                   immediate when ((wb_src = "11") and (auipc_sel ='0')) else
                   jump_addr when ((wb_src = "11") and (auipc_sel ='1')) else
                   (others => '0');
    
    pc_next     <= return_addr when (pc_src_o = PC_DEFAULT) else
                   jump_addr when (pc_src_o = BRANCH) else
                   jump_addr when ((jalr_sel = '0') and (pc_src_o = JUMP)) else
                   (alu_res(DATA_WIDTH - 1 downto 1) & '0') when ((jalr_sel = '1') and (pc_src_o = JUMP)) else
                   (others => '0');

    
    -- Hardware assignment
    gpio_o <= gpio_reg(6 downto 0);


    -- Debug simulation signals assignment 
    -- rs1_o        <= rs1;         
    -- rd_o         <= rd;          -- Address of the register where rf_wdata will be writed back
    -- rs2_o        <= rs2;
    -- imm          <= immediate;  
    -- alu_res_o    <= alu_res;     -- ALU output (address of the data in the dmem)
    -- alu_status_o <= alu_status;
    -- rf_wd        <= rf_wdata;    -- data writed back to register
    -- pc_out       <= pc_current;      -- Address of the next instruction in the imem
    -- pc_source    <= pc_src_o;
    -- instruction  <= imem_data_o ; -- Instruction from imem
    -- rs1_data_o   <= rs1_data;    -- Containt of register at the address
    -- rs2_data_o   <= rs2_data;    -- Data wrote back in dmem

end architecture rtl;