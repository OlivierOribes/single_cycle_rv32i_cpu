--==============================================================================
--  Module      : Register File Testbench
--  File        : tb_register_file.vhd
--  Description : Testbench for the RISC-V register file module.
--                No external dependencies (no OSVVM, no extra packages).
--
--  Author      : Olivier Oribes
--  Created     : 25/03/2026
--  Last update : 30/03/2026
--  Version     : 2.0
--  Project     : CPU_Single_cycle
--  Language    : VHDL
--==============================================================================
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_register_file is
end entity tb_register_file;

architecture sim of tb_register_file is

    -- ------------------------------------------------------------------
    -- slv_to_hstring : std_logic_vector -> hex string (no VHDL-2008 needed)
    -- ------------------------------------------------------------------
    function slv_to_hstring(slv : std_logic_vector) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        constant PAD_LEN   : integer := ((slv'length + 3) / 4) * 4;
        variable padded    : std_logic_vector(PAD_LEN - 1 downto 0) := (others => '0');
        variable nibble    : std_logic_vector(3 downto 0);
        variable result    : string(1 to PAD_LEN / 4);
        variable idx       : integer;
    begin
        padded(slv'length - 1 downto 0) := slv;
        for i in result'range loop
            nibble := padded(PAD_LEN - 1 - (i-1)*4 downto PAD_LEN - i*4);
            idx    := to_integer(unsigned(nibble));
            result(i) := HEX_CHARS(idx + 1);
        end loop;
        return result;
    end function;

    -- ------------------------------------------------------------------
    -- pseudo_rand : simple LFSR-based 32-bit pseudo-random generator
    -- seed must be non-zero
    -- ------------------------------------------------------------------
    function pseudo_rand(seed : std_logic_vector(31 downto 0))
        return std_logic_vector is
        variable s : std_logic_vector(31 downto 0) := seed;
        variable b : std_logic;
    begin
        -- Galois LFSR taps: 32, 22, 2, 1
        b  := s(31) xor s(21) xor s(1) xor s(0);
        s  := b & s(31 downto 1);
        return s;
    end function;

    -- ------------------------------------------------------------------
    -- Constants / signals
    -- ------------------------------------------------------------------
    constant WIDTH        : integer := 32;
    constant C_CLK_PERIOD : time    := 10 ns;
    constant ZERO : std_logic_vector(WIDTH-1 downto 0) := (others => '0');

    signal clk          : std_logic := '0';
    signal rst_n        : std_logic := '0';
    signal write_enable : std_logic := '0';
    signal rs1          : std_logic_vector(4 downto 0) := (others => '0');
    signal rs2          : std_logic_vector(4 downto 0) := (others => '0');
    signal rd           : std_logic_vector(4 downto 0) := (others => '0');
    signal write_data   : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal rs1_data     : std_logic_vector(WIDTH-1 downto 0);
    signal rs2_data     : std_logic_vector(WIDTH-1 downto 0);

begin

    -- ------------------------------------------------------------------
    -- DUT
    -- ------------------------------------------------------------------
    DUT : entity work.register_file
        generic map (WIDTH => WIDTH)
        port map (
            clk          => clk,
            rst_n        => rst_n,
            write_enable => write_enable,
            rs1          => rs1,
            rs2          => rs2,
            rd           => rd,
            write_data   => write_data,
            rs1_data     => rs1_data,
            rs2_data     => rs2_data
        );

    -- ------------------------------------------------------------------
    -- Clock generation : 100 MHz
    -- ------------------------------------------------------------------
    clk <= not clk after C_CLK_PERIOD / 2;

    -- ------------------------------------------------------------------
    -- Stimulus
    -- ------------------------------------------------------------------
    STIM : process
        variable error_count : integer := 0;
        variable rand_vec    : std_logic_vector(31 downto 0) := x"DEADBEEF";
        variable rand_addr   : std_logic_vector(4 downto 0);
        variable rand_data   : std_logic_vector(WIDTH-1 downto 0);
        variable addr_a      : std_logic_vector(4 downto 0);
        variable addr_b      : std_logic_vector(4 downto 0);
        variable data_a      : std_logic_vector(WIDTH-1 downto 0);
        variable data_b      : std_logic_vector(WIDTH-1 downto 0);

        -- Advance LFSR and return next 32-bit value
        procedure next_rand(variable v : inout std_logic_vector(31 downto 0)) is
        begin
            v := pseudo_rand(v);
        end procedure;

        -- Return a register address in [1..31] from current rand_vec
        procedure rand_reg_addr(variable v    : inout std_logic_vector(31 downto 0);
                                variable addr : out   std_logic_vector(4 downto 0)) is
            variable raw : integer;
        begin
            next_rand(v);
            raw  := to_integer(unsigned(v(4 downto 0)));
            if raw = 0 then raw := 1; end if;   -- never x0
            addr := std_logic_vector(to_unsigned(raw, 5));
        end procedure;

    begin

        -- ----------------------------------------------------------------
        -- Init
        -- ----------------------------------------------------------------
        rst_n        <= '0';
        write_enable <= '0';
        write_data   <= (others => '0');
        rs1          <= (others => '0');
        rs2          <= (others => '0');
        rd           <= (others => '0');

        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- ================================================================
        -- TEST 1 : Reset — tous les registres doivent être à zéro
        -- ================================================================
        report "==== TEST 1: Reset behavior ====" severity note;

        for i in 0 to 31 loop
            rs1 <= std_logic_vector(to_unsigned(i, 5));
            rs2 <= std_logic_vector(to_unsigned(i, 5));
            wait until rising_edge(clk);

            if rs1_data /= ZERO then
                report "ERROR TEST1 rs1: x" & integer'image(i) &
                       " = 0x" & slv_to_hstring(rs1_data) &
                       " (expected 0x00000000)" severity error;
                error_count := error_count + 1;
            end if;

            if rs2_data /= ZERO then
                report "ERROR TEST1 rs2: x" & integer'image(i) &
                       " = 0x" & slv_to_hstring(rs2_data) &
                       " (expected 0x00000000)" severity error;
                error_count := error_count + 1;
            end if;
        end loop;

        rst_n        <= '1';
        write_enable <= '1';
        wait until rising_edge(clk);

        -- ================================================================
        -- TEST 2 : Write then read via rs1
        -- ================================================================
        report "==== TEST 2: Write and read via rs1 ====" severity note;

        for i in 0 to 31 loop
            rand_reg_addr(rand_vec, rand_addr);
            next_rand(rand_vec);
            rand_data := rand_vec;

            rd         <= rand_addr;
            rs1        <= rand_addr;
            write_data <= rand_data;

            wait until rising_edge(clk);  -- write
            wait until rising_edge(clk);  -- read settles

            if rs1_data /= rand_data then
                report "ERROR TEST2: rs1_data = 0x" & slv_to_hstring(rs1_data) &
                       " (expected 0x" & slv_to_hstring(rand_data) & ")"
                       severity error;
                error_count := error_count + 1;
            end if;
        end loop;

        -- ================================================================
        -- TEST 3 : Write then read via rs2
        -- ================================================================
        report "==== TEST 3: Write and read via rs2 ====" severity note;

        for i in 0 to 31 loop
            rand_reg_addr(rand_vec, rand_addr);
            next_rand(rand_vec);
            rand_data := rand_vec;

            rd         <= rand_addr;
            rs2        <= rand_addr;
            write_data <= rand_data;

            wait until rising_edge(clk);  -- write
            wait until rising_edge(clk);  -- read settles

            if rs2_data /= rand_data then
                report "ERROR TEST3: rs2_data = 0x" & slv_to_hstring(rs2_data) &
                       " (expected 0x" & slv_to_hstring(rand_data) & ")"
                       severity error;
                error_count := error_count + 1;
            end if;
        end loop;

        -- ================================================================
        -- TEST 4 : Protection x0 — toujours zéro
        -- ================================================================
        report "==== TEST 4: x0 write-protection ====" severity note;

        for i in 0 to 7 loop
            next_rand(rand_vec);
            rand_data  := rand_vec;
            rd         <= (others => '0');
            rs1        <= (others => '0');
            rs2        <= (others => '0');
            write_data <= rand_data;

            wait until rising_edge(clk);
            wait until rising_edge(clk);

            if rs1_data /= ZERO then
                report "ERROR TEST4: x0 rs1_data = 0x" &
                       slv_to_hstring(rs1_data) &
                       " after write of 0x" & slv_to_hstring(rand_data)
                       severity error;
                error_count := error_count + 1;
            end if;

            if rs2_data /= ZERO then
                report "ERROR TEST4: x0 rs2_data = 0x" &
                       slv_to_hstring(rs2_data) &
                       " after write of 0x" & slv_to_hstring(rand_data)
                       severity error;
                error_count := error_count + 1;
            end if;
        end loop;

        -- ================================================================
        -- TEST 5 : Lecture simultanée rs1 / rs2
        -- ================================================================
        report "==== TEST 5: Simultaneous rs1/rs2 read ====" severity note;

        addr_a := std_logic_vector(to_unsigned(5,  5));
        addr_b := std_logic_vector(to_unsigned(10, 5));
        next_rand(rand_vec); data_a := rand_vec;
        next_rand(rand_vec); data_b := rand_vec;

        -- Ecrire registre A
        rd <= addr_a; rs1 <= addr_a; write_data <= data_a;
        wait until rising_edge(clk);

        -- Ecrire registre B
        rd <= addr_b; rs2 <= addr_b; write_data <= data_b;
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- Lecture simultanée
        rs1          <= addr_a;
        rs2          <= addr_b;
        write_enable <= '0';
        wait until rising_edge(clk);

        if rs1_data /= data_a then
            report "ERROR TEST5: rs1_data (x5) = 0x" &
                   slv_to_hstring(rs1_data) &
                   " (expected 0x" & slv_to_hstring(data_a) & ")"
                   severity error;
            error_count := error_count + 1;
        end if;

        if rs2_data /= data_b then
            report "ERROR TEST5: rs2_data (x10) = 0x" &
                   slv_to_hstring(rs2_data) &
                   " (expected 0x" & slv_to_hstring(data_b) & ")"
                   severity error;
            error_count := error_count + 1;
        end if;

        -- ================================================================
        -- Fin de simulation
        -- ================================================================
        if error_count = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report "SIMULATION FINISHED WITH " &
                   integer'image(error_count) & " ERROR(S)"
                   severity failure;
        end if;

        report "End of simulation" severity note;
        wait;

    end process STIM;

end architecture sim;