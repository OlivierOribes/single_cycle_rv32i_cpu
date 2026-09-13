<h1 align="center">
Single-cycle RV32I CPU
</h1>


<p align="center">
Design and implementation of a complete single-cycle RISC-V CPU in VHDL.
</p>

To gain a comprehensive understanding of CPU architecture and the distinction between hardware and software layers, I started this project.
The goal is to design and implement a complete single-cycle CPU based on the RISC-V architecture. For simplicity, this implementation will support only the RV32I base integer instruction set.
Once all instructions have been implemented and validated through simulations using ModelSim, the processor will be synthesized and tested on hardware using Vivado 2025.2 and a Zybo Z7 FPGA development board.

## Architecture overview

The CPU is a classic **single-cycle RV32I** design: every instruction is fetched, decoded, executed, and (if needed) writes back to memory/registers within one clock period — there is no pipelining. The top-level entity is [`cpu.vhd`](src/CPU_top/cpu.vhd), which wires together the following modules:

| Module | Role |
|---|---|
| [`imem.vhd`](src/CPU_top/imem.vhd) | Instruction ROM, initialized from a `.hex` file, read combinationally at `pc_current` |
| [`control_unit.vhd`](src/CPU_top/control_unit.vhd) | Decodes the instruction into ALU op, mux selects, register-file write enable, memory access type, etc. |
| [`Register_file.vhd`](src/CPU_top/Register_file.vhd) | 32×32-bit register file (x0 hardwired to zero), two async read ports, one sync write port |
| [`ALU.vhd`](src/CPU_top/ALU.vhd) | Arithmetic/logic core, also produces the status flags (Zero, Negative, Carry, Overflow) used for branches |
| [`sign_extender.vhd`](src/CPU_top/sign_extender.vhd) | Builds the sign/zero-extended immediate from the raw instruction bits, based on instruction type |
| [`dmem.vhd`](src/CPU_top/dmem.vhd) | Data RAM with per-byte write enable (supports word/half-word/byte accesses) and async read |
| [`wizard_clock.vhd`](src/CPU_top/wizard_clock.vhd) | Divides the board's 100 MHz clock down to a slower `clk` used by the whole datapath |

### One instruction, one cycle

1. **Fetch** — `pc_current` addresses `imem`, which returns the current instruction combinationally.
2. **Decode** — `control_unit` splits the instruction into opcode/funct3/funct7/register fields and derives every control signal; `sign_extender` builds the immediate in parallel.
3. **Execute** — the register file supplies `rs1`/`rs2`, a mux picks the ALU's second operand (register or immediate), and the ALU computes the result and status flags. Those flags feed back into `control_unit` to resolve branch conditions (BEQ/BNE/BLT/BGE/BLTU/BGEU).
4. **Memory** — for loads/stores, the ALU result is used as the address into `dmem`; `byte_en` selects which byte lanes are read/written, enabling byte/half-word/word accesses.
5. **Write-back** — a mux selects what gets written into the destination register: the ALU result, memory data, `pc+4` (for JAL/JALR), or the immediate/PC-relative address (for LUI/AUIPC). `pc_next` is computed the same cycle (sequential/branch/jump) and latched into `pc_current` on the next rising edge.

### Supported instructions

R-type (ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA), I-type ALU (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI), loads/stores (LW, LH, LHU, LB, LBU, SW, SH, SB), all branches, JAL, JALR, LUI and AUIPC.

### Memory-mapped I/O

A single GPIO register is memory-mapped: a `SW` to `GPIO_LED_ADDR` (see [`cpu_pkg.vhd`](src/CPU_top/cpu_pkg.vhd)) latches into `gpio_reg`, whose low 7 bits drive `gpio_o` (the board's LEDs).

### Clock

`clk_i` (the board's 100 MHz oscillator) is divided by [`wizard_clock.vhd`](src/CPU_top/wizard_clock.vhd) into the `clk` used everywhere else in the datapath, so the CPU visibly runs slow enough to see the LEDs blink.

