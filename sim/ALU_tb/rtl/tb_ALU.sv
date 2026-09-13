`timescale 1ns/1ps
//==============================================================================
//  Module      : ALU Testbench — exhaustive version
//  File        : ALU_tb.sv
//  Description : Directed tests + random loops + corner cases
//                to fully validate the combinational ALU.
//
//  Testing strategy:
//    1. Directed corner cases (0, 1, -1, MIN_INT, MAX_INT, patterns)
//    2. Random loops (N draws per opcode, SV golden model)
//    3. Cross-check of all flags (C, Z, N, V)
//    4. Algebraic properties (commutativity, ADD/SUB inverse, XOR self-inverse)
//
//  Status_out = {C[3], Z[2], N[1], V[0]}
//    C : carry (ADD) / borrow active-high (SUB)
//    Z : result = 0
//    N : MSB of result
//    V : signed overflow (ADD/SUB only)
//==============================================================================

module ALU_tb;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam DATA_WIDTH = 32;
    localparam N_RANDOM   = 2000;   // random draws per opcode

    // Corner case constants
    localparam logic [DATA_WIDTH-1:0] ZERO    = 32'h0000_0000;
    localparam logic [DATA_WIDTH-1:0] ONE     = 32'h0000_0001;
    localparam logic [DATA_WIDTH-1:0] ALL1    = 32'hFFFF_FFFF;  // -1 signed
    localparam logic [DATA_WIDTH-1:0] MAX_INT = 32'h7FFF_FFFF;  // +2147483647
    localparam logic [DATA_WIDTH-1:0] MIN_INT = 32'h8000_0000;  // -2147483648
    localparam logic [DATA_WIDTH-1:0] MSB     = 32'h8000_0000;
    localparam logic [DATA_WIDTH-1:0] PAT_AA  = 32'hAAAA_AAAA;
    localparam logic [DATA_WIDTH-1:0] PAT_55  = 32'h5555_5555;

    // Values mirror the position of each literal in work.cpu_pkg.alu_op_t
    // (src/CPU_top/cpu_pkg.vhd) — ALU_ctrl on the DUT is that VHDL enum, and
    // ModelSim's VHDL/SV boundary maps enumeration ports by position index,
    // not by an arbitrary bit pattern.
    typedef enum logic[3:0]{
        ALU_NOP  = 4'd0,
        ALU_ADD  = 4'd1,
        ALU_SUB  = 4'd2,
        ALU_AND  = 4'd3,
        ALU_OR   = 4'd4,
        ALU_XOR  = 4'd5,
        ALU_SLL  = 4'd6,
        ALU_SRL  = 4'd7,
        ALU_SRA  = 4'd8,
        ALU_SLT  = 4'd9,
        ALU_SLTU = 4'd10
    } alu_op_t;
    // =========================================================================
    // Signals
    // =========================================================================
    logic [3:0]            ALU_control;
    logic [DATA_WIDTH-1:0] A, B, Y;
    logic [3:0]            Status_out;

    // =========================================================================
    // DUT
    // =========================================================================
    ALU_dut_wrapper dut (
        .ALU_ctrl    (ALU_control),
        .A           (A),
        .B           (B),
        .Status_out  (Status_out),
        .Y           (Y)
    );

    // =========================================================================
    // Global counters
    // =========================================================================
    int error_count = 0;
    int test_count  = 0;

    // =========================================================================
    // SV golden model — purely behavioural reference
    // Computes expected result and all 4 flags for (op, a, b).
    // =========================================================================
    task automatic golden_model(
        input  alu_op_t                op,
        input  logic [DATA_WIDTH-1:0] a,
        input  logic [DATA_WIDTH-1:0] b,
        output logic [DATA_WIDTH-1:0] exp_y,
        output logic                  exp_C,
        output logic                  exp_Z,
        output logic                  exp_N,
        output logic                  exp_V
    );

        logic [DATA_WIDTH:0] ext;
        exp_C = 0; exp_V = 0;

        case (op)
            ALU_AND: exp_y = a & b;
            ALU_OR:  exp_y = a | b;
            ALU_XOR: exp_y = a ^ b;

            ALU_ADD: begin  // ADD
                ext   = {1'b0, a} + {1'b0, b};
                exp_y = ext[DATA_WIDTH-1:0];
                exp_C = ext[DATA_WIDTH];
                exp_V = (a[DATA_WIDTH-1] == b[DATA_WIDTH-1]) &&
                        (exp_y[DATA_WIDTH-1] != a[DATA_WIDTH-1]);
            end

            ALU_SUB: begin  // SUB — borrow is active when A < B (unsigned)
                ext   = {1'b0, a} - {1'b0, b};
                exp_y = ext[DATA_WIDTH-1:0];
                exp_C = ext[DATA_WIDTH];
                exp_V = (a[DATA_WIDTH-1] != b[DATA_WIDTH-1]) &&
                        (exp_y[DATA_WIDTH-1] != a[DATA_WIDTH-1]);
            end

            ALU_SLT: begin  // SLT signed comparison
                exp_y = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0;
                exp_C = 0;
                exp_V = 0;
            end

            ALU_SLTU: begin  // SLTU unsigned comparison
                exp_y = ($unsigned(a) < $unsigned(b)) ? 32'h1 : 32'h0;
                exp_C = 0;
                exp_V = 0;
            end

            ALU_SLL: begin  // SLL : shift left logical by B (no carry)
                exp_y = a << b;
            end

            ALU_SRL: begin  // SRL : shift right logical by B (no carry)
                exp_y = a >> b;
            end

            ALU_SRA: begin  // SRA : shift right arithmetic by B, sign-extended (no carry)
                exp_y = DATA_WIDTH'($signed(a) >>> b);
            end

            default: begin
                exp_y = '0;
                exp_C = 0;
                exp_V = 0;
            end
        endcase

        exp_Z = (exp_y == '0);
        exp_N = exp_y[DATA_WIDTH-1];
    endtask

    // =========================================================================
    // Task : drive one stimulus, compare against golden model, log errors
    // =========================================================================
    task automatic check(
        input logic [3:0]            op,
        input logic [DATA_WIDTH-1:0] a,
        input logic [DATA_WIDTH-1:0] b,
        input string                 test_name
    );
        logic [DATA_WIDTH-1:0] exp_y;
        logic exp_C, exp_Z, exp_N, exp_V;
        logic fail;

        golden_model(alu_op_t'(op), a, b, exp_y, exp_C, exp_Z, exp_N, exp_V);

        ALU_control = op;
        A = a;
        B = b;
        #1;

        fail = 0;
        test_count++;

        if (Y !== exp_y) begin
            $error("[%s] Y  exp=0x%08h got=0x%08h  A=0x%08h B=0x%08h op=%b",
                   test_name, exp_y, Y, a, b, op);
            fail = 1;
        end
        if (Status_out[3] !== exp_C) begin
            $error("[%s] C  exp=%b got=%b  A=0x%08h B=0x%08h op=%b",
                   test_name, exp_C, Status_out[3], a, b, op);
            fail = 1;
        end
        if (Status_out[2] !== exp_Z) begin
            $error("[%s] Z  exp=%b got=%b  A=0x%08h B=0x%08h op=%b",
                   test_name, exp_Z, Status_out[2], a, b, op);
            fail = 1;
        end
        if (Status_out[1] !== exp_N) begin
            $error("[%s] N  exp=%b got=%b  A=0x%08h B=0x%08h op=%b",
                   test_name, exp_N, Status_out[1], a, b, op);
            fail = 1;
        end
        if (Status_out[0] !== exp_V) begin
            $error("[%s] V  exp=%b got=%b  A=0x%08h B=0x%08h op=%b",
                   test_name, exp_V, Status_out[0], a, b, op);
            fail = 1;
        end

        if (fail) error_count++;
    endtask

    // =========================================================================
    // Task : random loop — N_RANDOM draws for a given opcode
    // =========================================================================
    task automatic random_loop(input logic [3:0] op, input string op_name);
        logic [DATA_WIDTH-1:0] ra, rb;
        $display("  [random %0d] %s ...", N_RANDOM, op_name);
        for (int i = 0; i < N_RANDOM; i++) begin
            ra = $urandom();
            rb = $urandom();
            check(op, ra, rb, $sformatf("%s_rnd_%0d", op_name, i));
        end
    endtask

    // =========================================================================
    // Task : cartesian product of 8 corner values for two operands
    // =========================================================================
    task automatic edge_cases_2op(input logic [3:0] op, input string op_name);
        logic [DATA_WIDTH-1:0] corners [8] = '{
            ZERO, ONE, ALL1, MAX_INT, MIN_INT, MSB, PAT_AA, PAT_55
        };
        $display("  [edges 8x8=64] %s ...", op_name);
        foreach (corners[i])
            foreach (corners[j])
                check(op, corners[i], corners[j],
                      $sformatf("%s_e%0d_%0d", op_name, i, j));
    endtask

    // =========================================================================
    // Task : corner cases for shifts — B is the shift amount, held fixed
    // =========================================================================
    task automatic edge_cases_shift(input logic [3:0] op, input string op_name,
                                     input logic [DATA_WIDTH-1:0] shamt);
        logic [DATA_WIDTH-1:0] corners [8] = '{
            ZERO, ONE, ALL1, MAX_INT, MIN_INT, MSB, PAT_AA, PAT_55
        };
        $display("  [edges 8] %s ...", op_name);
        foreach (corners[i])
            check(op, corners[i], shamt, $sformatf("%s_e%0d", op_name, i));
    endtask

    // =========================================================================
    // TEST SEQUENCE
    // =========================================================================
    initial begin
        $display("\n========================================================");
        $display("  ALU TESTBENCH ");
        $display("  DATA_WIDTH=%0d   N_RANDOM=%0d/opcode", DATA_WIDTH, N_RANDOM);
        $display("========================================================\n");

        // ------------------------------------------------------------------ //
        //  AND  0000                                                          //
        // ------------------------------------------------------------------ //
        $display("=== AND (0000) ===");
        edge_cases_2op(ALU_AND, "AND");
        random_loop   (ALU_AND, "AND");

        // ------------------------------------------------------------------ //
        //  OR   0001                                                          //
        // ------------------------------------------------------------------ //
        $display("=== OR  (0001) ===");
        edge_cases_2op(ALU_OR, "OR");
        random_loop   (ALU_OR, "OR");

        // ------------------------------------------------------------------ //
        //  XOR  0011                                                          //
        // ------------------------------------------------------------------ //
        $display("=== XOR (0011) ===");
        edge_cases_2op(ALU_XOR, "XOR");
        random_loop   (ALU_XOR, "XOR");

        // ------------------------------------------------------------------ //
        //  ADD  0010 — additional directed cases before random loops         //
        // ------------------------------------------------------------------ //
        $display("=== ADD (0010) ===");
        $display("  [directed] ...");
        check(ALU_ADD, ZERO,    ZERO,    "ADD_0+0");          // Z=1
        check(ALU_ADD, ONE,     ZERO,    "ADD_1+0");          // right identity
        check(ALU_ADD, ZERO,    ONE,     "ADD_0+1");          // left identity
        check(ALU_ADD, ALL1,    ONE,     "ADD_-1+1");         // carry out, Z=1
        check(ALU_ADD, ALL1,    ALL1,    "ADD_-1+-1");        // carry, N=1
        check(ALU_ADD, MAX_INT, ONE,     "ADD_MAX+1");        // positive overflow → negative result
        check(ALU_ADD, MAX_INT, MAX_INT, "ADD_MAX+MAX");      // overflow + carry
        check(ALU_ADD, MIN_INT, MIN_INT, "ADD_MIN+MIN");      // negative overflow → positive + carry
        check(ALU_ADD, MIN_INT, ALL1,    "ADD_MIN+(-1)");     // neg+neg → positive, overflow
        check(ALU_ADD, PAT_AA,  PAT_55,  "ADD_AA+55");        // = 0xFFFFFFFF
        check(ALU_ADD, PAT_55,  PAT_55,  "ADD_55+55");
        check(ALU_ADD, PAT_AA,  PAT_AA,  "ADD_AA+AA");        // carry + overflow
        edge_cases_2op(ALU_ADD, "ADD");
        random_loop   (ALU_ADD, "ADD");

        // ------------------------------------------------------------------ //
        //  SUB  0110 — additional directed cases before random loops         //
        // ------------------------------------------------------------------ //
        $display("=== SUB (0110) ===");
        $display("  [directed] ...");
        check(ALU_SUB, ZERO,    ZERO,    "SUB_0-0");          // Z=1
        check(ALU_SUB, ONE,     ZERO,    "SUB_1-0");          // right identity
        check(ALU_SUB, ZERO,    ONE,     "SUB_0-1");          // underflow, borrow=1, N=1
        check(ALU_SUB, ONE,     ONE,     "SUB_1-1");          // Z=1
        check(ALU_SUB, ALL1,    ALL1,    "SUB_-1-(-1)");      // Z=1
        check(ALU_SUB, ZERO,    ALL1,    "SUB_0-(-1)");       // borrow, result = 1
        check(ALU_SUB, MAX_INT, MIN_INT, "SUB_MAX-MIN");      // positive minus negative → negative, overflow
        check(ALU_SUB, MIN_INT, ONE,     "SUB_MIN-1");        // negative minus positive → positive, overflow
        check(ALU_SUB, MIN_INT, MAX_INT, "SUB_MIN-MAX");      // borrow and signed overflow
        check(ALU_SUB, PAT_AA,  PAT_55,  "SUB_AA-55");
        check(ALU_SUB, PAT_55,  PAT_AA,  "SUB_55-AA");        // borrow
        edge_cases_2op(ALU_SUB, "SUB");
        random_loop   (ALU_SUB, "SUB");

        // ------------------------------------------------------------------ //
        //  SLT  0111                                                          //
        // ------------------------------------------------------------------ //
        $display("=== SLT (0111) ===");
        $display("  [directed] ...");
        check(ALU_SLT, ZERO,    ONE,     "SLT_0<1");          // 1
        check(ALU_SLT, ONE,     ZERO,    "SLT_1<0");          // 0
        check(ALU_SLT, ZERO,    ZERO,    "SLT_0<0");          // 0
        check(ALU_SLT, MIN_INT, ZERO,    "SLT_MIN<0");        // 1 (negative < 0)
        check(ALU_SLT, ZERO,    MIN_INT, "SLT_0<MIN");        // 0
        check(ALU_SLT, MIN_INT, MAX_INT, "SLT_MIN<MAX");      // 1
        check(ALU_SLT, MAX_INT, MIN_INT, "SLT_MAX<MIN");      // 0
        check(ALU_SLT, ALL1,    ZERO,    "SLT_-1<0");         // 1
        check(ALU_SLT, ZERO,    ALL1,    "SLT_0<-1");         // 0
        edge_cases_2op(ALU_SLT, "SLT");
        random_loop   (ALU_SLT, "SLT");

        // ------------------------------------------------------------------ //
        //  SLTU — unsigned comparison                                        //
        // ------------------------------------------------------------------ //
        $display("=== SLTU ===");
        $display("  [directed] ...");
        check(ALU_SLTU, ZERO,    ONE,     "SLTU_0<1");          // 1
        check(ALU_SLTU, ONE,     ZERO,    "SLTU_1<0");          // 0
        check(ALU_SLTU, ZERO,    ZERO,    "SLTU_0<0");          // 0
        check(ALU_SLTU, ZERO,    ALL1,    "SLTU_0<FFFFFFFF");   // 1 (max unsigned)
        check(ALU_SLTU, ALL1,    ZERO,    "SLTU_FFFFFFFF<0");   // 0
        check(ALU_SLTU, MAX_INT, MIN_INT, "SLTU_7FFFFFFF<80000000"); // 1 (unsigned: MIN_INT is larger)
        check(ALU_SLTU, MIN_INT, MAX_INT, "SLTU_80000000<7FFFFFFF"); // 0
        check(ALU_SLTU, PAT_55,  PAT_AA,  "SLTU_55<AA");        // 1
        check(ALU_SLTU, PAT_AA,  PAT_55,  "SLTU_AA<55");        // 0
        edge_cases_2op(ALU_SLTU, "SLTU");
        random_loop   (ALU_SLTU, "SLTU");

        // ------------------------------------------------------------------ //
        //  SLL — shift left logical by B, no carry                          //
        // ------------------------------------------------------------------ //
        $display("=== SLL ===");
        $display("  [directed] ...");
        check(ALU_SLL, ZERO,    ONE,     "SLL_0<<1");          // 0<<1=0
        check(ALU_SLL, ONE,     ONE,     "SLL_1<<1");          // 1<<1=2
        check(ALU_SLL, MSB,     ONE,     "SLL_MSB<<1");        // MSB evicted, Y=0
        check(ALU_SLL, MAX_INT, ONE,     "SLL_MAX<<1");        // 7FFF...→FFFE, N=1
        check(ALU_SLL, ALL1,    ONE,     "SLL_FF<<1");         // 0xFFFFFFFE
        check(ALU_SLL, PAT_AA,  ONE,     "SLL_AA<<1");
        check(ALU_SLL, PAT_55,  ONE,     "SLL_55<<1");
        check(ALU_SLL, ONE,     ZERO,    "SLL_shamt0");        // shift by 0 = identity
        check(ALU_SLL, ONE,     32'd31,  "SLL_shamt31");       // 1<<31 = MSB
        check(ALU_SLL, ONE,     32'd32,  "SLL_shamt32");       // shift >= width -> 0
        edge_cases_shift(ALU_SLL, "SLL", ONE);
        random_loop     (ALU_SLL, "SLL");

        // ------------------------------------------------------------------ //
        //  SRL — shift right logical by B, no carry                         //
        // ------------------------------------------------------------------ //
        $display("=== SRL ===");
        $display("  [directed] ...");
        check(ALU_SRL, ZERO,    ONE,     "SRL_0>>1");          // 0>>1=0
        check(ALU_SRL, MSB,     ONE,     "SRL_MSB>>1");        // 0x4000_0000
        check(ALU_SRL, ALL1,    ONE,     "SRL_FF>>1");         // 0x7FFF_FFFF
        check(ALU_SRL, PAT_AA,  ONE,     "SRL_AA>>1");
        check(ALU_SRL, PAT_55,  ONE,     "SRL_55>>1");
        check(ALU_SRL, ALL1,    32'd31,  "SRL_shamt31");       // 0x0000_0001
        check(ALU_SRL, ALL1,    32'd32,  "SRL_shamt32");       // shift >= width -> 0
        edge_cases_shift(ALU_SRL, "SRL", ONE);
        random_loop     (ALU_SRL, "SRL");

        // ------------------------------------------------------------------ //
        //  SRA — shift right arithmetic by B, sign-extended, no carry       //
        // ------------------------------------------------------------------ //
        $display("=== SRA ===");
        $display("  [directed] ...");
        check(ALU_SRA, ZERO,    ONE,     "SRA_0>>>1");         // 0
        check(ALU_SRA, ONE,     ONE,     "SRA_1>>>1");         // 0
        check(ALU_SRA, MSB,     ONE,     "SRA_MSB>>>1");       // sign-extend: 0xC000_0000
        check(ALU_SRA, ALL1,    ONE,     "SRA_FF>>>1");        // -1>>>1 = -1 = 0xFFFFFFFF
        check(ALU_SRA, MAX_INT, ONE,     "SRA_MAX>>>1");       // 0x3FFF_FFFF
        check(ALU_SRA, MIN_INT, ONE,     "SRA_MIN>>>1");       // 0xC000_0000
        check(ALU_SRA, MSB,     32'd31,  "SRA_MSB>>>31");      // all 1s (sign fill)
        check(ALU_SRA, MAX_INT, 32'd31,  "SRA_MAX>>>31");      // all 0s
        check(ALU_SRA, MSB,     ZERO,    "SRA_shamt0");        // identity
        edge_cases_shift(ALU_SRA, "SRA", ONE);
        random_loop     (ALU_SRA, "SRA");

        // ------------------------------------------------------------------ //
        //  NOP — falls into the DUT's `when others`: Y=0, all flags=0        //
        //  (alu_op_t is a closed enum; there is no other "unknown" encoding) //
        // ------------------------------------------------------------------ //
        $display("=== NOP ===");
        check(ALU_NOP, 32'hDEAD_BEEF, 32'hCAFE_BABE, "NOP");

        // ------------------------------------------------------------------ //
        //  Property : commutativity (ADD, AND, OR, XOR)                     //
        //  f(a,b) == f(b,a) for 500 random pairs per opcode                 //
        // ------------------------------------------------------------------ //
        $display("=== Commutativity check ===");
        begin
            automatic logic [3:0] com_ops [4] = '{
                ALU_ADD, ALU_AND, ALU_OR, ALU_XOR
            };

            automatic string com_names[4] = '{
                "ADD","AND","OR","XOR"
            };
            logic [DATA_WIDTH-1:0] ra, rb, y_ab, y_ba;

            for (int i = 0; i < 4; i++) begin
                $display("  [commut 500] %s ...", com_names[i]);
                for (int k = 0; k < 500; k++) begin
                    ra = $urandom(); rb = $urandom();
                    ALU_control = com_ops[i]; A = ra; B = rb; #1; y_ab = Y;
                    ALU_control = com_ops[i]; A = rb; B = ra; #1; y_ba = Y;
                    test_count++;
                    if (y_ab !== y_ba) begin
                        $error("[commut_%s] f(0x%h,0x%h)=0x%h != f(0x%h,0x%h)=0x%h",
                               com_names[i], ra, rb, y_ab, rb, ra, y_ba);
                        error_count++;
                    end
                end
            end
        end

        // ------------------------------------------------------------------ //
        //  Property : ADD/SUB inverse — (A + B) - B == A                   //
        // ------------------------------------------------------------------ //
        $display("=== ADD/SUB inverse check (1000 pairs) ===");
        begin
            logic [DATA_WIDTH-1:0] ra, rb, s, back;
            for (int k = 0; k < 1000; k++) begin
                ra = $urandom(); rb = $urandom();
                ALU_control = ALU_ADD; A = ra;  B = rb; #1; s    = Y;
                ALU_control = ALU_SUB; A = s;   B = rb; #1; back = Y;
                test_count++;
                if (back !== ra) begin
                    $error("[ADD_SUB_inv] (0x%h+0x%h)-0x%h=0x%h, exp=0x%h",
                           ra, rb, rb, back, ra);
                    error_count++;
                end
            end
        end

        // ------------------------------------------------------------------ //
        //  Property : XOR self-inverse — (A ^ B) ^ B == A                  //
        // ------------------------------------------------------------------ //
        $display("=== XOR self-inverse check (1000 pairs) ===");
        begin
            logic [DATA_WIDTH-1:0] ra, rb, xr, back;
            for (int k = 0; k < 1000; k++) begin
                ra = $urandom(); rb = $urandom();
                ALU_control = ALU_XOR; A = ra; B = rb; #1; xr   = Y;
                ALU_control = ALU_XOR; A = xr; B = rb; #1; back = Y;
                test_count++;
                if (back !== ra) begin
                    $error("[XOR_inv] (0x%h^0x%h)^0x%h=0x%h, exp=0x%h",
                           ra, rb, rb, back, ra);
                    error_count++;
                end
            end
        end

        // ------------------------------------------------------------------ //
        //  Property : SLL then SRL loses both MSB and LSB                  //
        //  Verify that SLL by 1 followed by SRL by 1 gives (A & 0x7FFFFFFF)//
        // ------------------------------------------------------------------ //
        $display("=== SLL then SRL consistency (500 values) ===");
        begin
            logic [DATA_WIDTH-1:0] ra, shifted, back;
            for (int k = 0; k < 500; k++) begin
                ra = $urandom();
                ALU_control = ALU_SLL; A = ra;      B = ONE; #1; shifted = Y;
                ALU_control = ALU_SRL; A = shifted; B = ONE; #1; back    = Y;
                test_count++;
                // SLL(ra,1)      = {ra[30:0], 1'b0}   — bit[0] becomes 0, ra[31] is evicted
                // SRL(SLL(ra),1) = {1'b0, ra[30:0]}   — bit[31] becomes 0, ra[0] is restored
                // Net effect     : ra with only bit[31] cleared → ra & 0x7FFFFFFF
                if (back !== (ra & 32'h7FFF_FFFF)) begin
                    $error("[SLL_SRL] ra=0x%h -> SLL=0x%h -> SRL=0x%h, exp=0x%h",
                           ra, shifted, back, ra & 32'h7FFF_FFFF);
                    error_count++;
                end
            end
        end

        // ------------------------------------------------------------------ //
        //  Final summary                                                     //
        // ------------------------------------------------------------------ //
        $display("\n========================================================");
        $display("  Total vectors : %0d", test_count);
        if (error_count == 0)
            $display("  RESULT  : ALL TESTS PASSED");
        else
            $display("  RESULT  : FAILED — %0d error(s)", error_count);
        $display("========================================================\n");

        $finish;
    end

endmodule
