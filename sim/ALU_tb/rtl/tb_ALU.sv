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
//    C : carry (ADD) / borrow active-high (SUB) / evicted bit (shifts)
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

    // =========================================================================
    // Signals
    // =========================================================================
    logic [3:0]            ALU_control;
    logic [DATA_WIDTH-1:0] A, B, Y;
    logic [3:0]            Status_out;

    // =========================================================================
    // DUT
    // =========================================================================
    ALU dut (
        .ALU_control (ALU_control),
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
        input  logic [3:0]            op,
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
            4'b0000: exp_y = a & b;
            4'b0001: exp_y = a | b;
            4'b0011: exp_y = a ^ b;
            4'b1100: exp_y = ~(a | b);

            4'b0010: begin  // ADD
                ext   = {1'b0, a} + {1'b0, b};
                exp_y = ext[DATA_WIDTH-1:0];
                exp_C = ext[DATA_WIDTH];
                exp_V = (a[DATA_WIDTH-1] == b[DATA_WIDTH-1]) &&
                        (exp_y[DATA_WIDTH-1] != a[DATA_WIDTH-1]);
            end

            4'b0110: begin  // SUB — borrow is active when A < B (unsigned)
                ext   = {1'b0, a} - {1'b0, b};
                exp_y = ext[DATA_WIDTH-1:0];
                exp_C = ext[DATA_WIDTH];
                exp_V = (a[DATA_WIDTH-1] != b[DATA_WIDTH-1]) &&
                        (exp_y[DATA_WIDTH-1] != a[DATA_WIDTH-1]);
            end

            4'b0111: begin  // SLT signed comparison
                exp_y = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0;
                exp_C = 0;
                exp_V = 0;
            end

            4'b1101: begin  // SHL ×1 -> exp_y = a << 1;
                exp_y = {a[DATA_WIDTH-2:0], 1'b0};
                exp_C = a[DATA_WIDTH-1];
            end

            4'b1110: begin  // SHR logical shift right by 1 -> exp_y = a >> 1;
                exp_y = {1'b0, a[DATA_WIDTH-1:1]};
                exp_C = a[0];
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

        golden_model(op, a, b, exp_y, exp_C, exp_Z, exp_N, exp_V);

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
    // Task : corner cases for shifts (B is don't-care)
    // =========================================================================
    task automatic edge_cases_shift(input logic [3:0] op, input string op_name);
        logic [DATA_WIDTH-1:0] corners [8] = '{
            ZERO, ONE, ALL1, MAX_INT, MIN_INT, MSB, PAT_AA, PAT_55
        };
        $display("  [edges 8] %s ...", op_name);
        foreach (corners[i])
            check(op, corners[i], ZERO, $sformatf("%s_e%0d", op_name, i));
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
        edge_cases_2op(4'b0000, "AND");
        random_loop   (4'b0000, "AND");

        // ------------------------------------------------------------------ //
        //  OR   0001                                                          //
        // ------------------------------------------------------------------ //
        $display("=== OR  (0001) ===");
        edge_cases_2op(4'b0001, "OR");
        random_loop   (4'b0001, "OR");

        // ------------------------------------------------------------------ //
        //  XOR  0011                                                          //
        // ------------------------------------------------------------------ //
        $display("=== XOR (0011) ===");
        edge_cases_2op(4'b0011, "XOR");
        random_loop   (4'b0011, "XOR");

        // ------------------------------------------------------------------ //
        //  NOR  1100                                                          //
        // ------------------------------------------------------------------ //
        $display("=== NOR (1100) ===");
        edge_cases_2op(4'b1100, "NOR");
        random_loop   (4'b1100, "NOR");

        // ------------------------------------------------------------------ //
        //  ADD  0010 — additional directed cases before random loops         //
        // ------------------------------------------------------------------ //
        $display("=== ADD (0010) ===");
        $display("  [directed] ...");
        check(4'b0010, ZERO,    ZERO,    "ADD_0+0");          // Z=1
        check(4'b0010, ONE,     ZERO,    "ADD_1+0");          // right identity
        check(4'b0010, ZERO,    ONE,     "ADD_0+1");          // left identity
        check(4'b0010, ALL1,    ONE,     "ADD_-1+1");         // carry out, Z=1
        check(4'b0010, ALL1,    ALL1,    "ADD_-1+-1");        // carry, N=1
        check(4'b0010, MAX_INT, ONE,     "ADD_MAX+1");        // positive overflow → negative result
        check(4'b0010, MAX_INT, MAX_INT, "ADD_MAX+MAX");      // overflow + carry
        check(4'b0010, MIN_INT, MIN_INT, "ADD_MIN+MIN");      // negative overflow → positive + carry
        check(4'b0010, MIN_INT, ALL1,    "ADD_MIN+(-1)");     // neg+neg → positive, overflow
        check(4'b0010, PAT_AA,  PAT_55,  "ADD_AA+55");        // = 0xFFFFFFFF
        check(4'b0010, PAT_55,  PAT_55,  "ADD_55+55");
        check(4'b0010, PAT_AA,  PAT_AA,  "ADD_AA+AA");        // carry + overflow
        edge_cases_2op(4'b0010, "ADD");
        random_loop   (4'b0010, "ADD");

        // ------------------------------------------------------------------ //
        //  SUB  0110 — additional directed cases before random loops         //
        // ------------------------------------------------------------------ //
        $display("=== SUB (0110) ===");
        $display("  [directed] ...");
        check(4'b0110, ZERO,    ZERO,    "SUB_0-0");          // Z=1
        check(4'b0110, ONE,     ZERO,    "SUB_1-0");          // right identity
        check(4'b0110, ZERO,    ONE,     "SUB_0-1");          // underflow, borrow=1, N=1
        check(4'b0110, ONE,     ONE,     "SUB_1-1");          // Z=1
        check(4'b0110, ALL1,    ALL1,    "SUB_-1-(-1)");      // Z=1
        check(4'b0110, ZERO,    ALL1,    "SUB_0-(-1)");       // borrow, result = 1
        check(4'b0110, MAX_INT, MIN_INT, "SUB_MAX-MIN");      // positive minus negative → negative, overflow
        check(4'b0110, MIN_INT, ONE,     "SUB_MIN-1");        // negative minus positive → positive, overflow
        check(4'b0110, MIN_INT, MAX_INT, "SUB_MIN-MAX");      // borrow and signed overflow
        check(4'b0110, PAT_AA,  PAT_55,  "SUB_AA-55");
        check(4'b0110, PAT_55,  PAT_AA,  "SUB_55-AA");        // borrow
        edge_cases_2op(4'b0110, "SUB");
        random_loop   (4'b0110, "SUB");

        // ------------------------------------------------------------------ //
        //  SLT  0111                                                          //
        // ------------------------------------------------------------------ //
        $display("=== SLT (0111) ===");
        $display("  [directed] ...");
        check(4'b0111, ZERO,    ONE,     "SLT_0<1");          // 1
        check(4'b0111, ONE,     ZERO,    "SLT_1<0");          // 0
        check(4'b0111, ZERO,    ZERO,    "SLT_0<0");          // 0
        check(4'b0111, MIN_INT, ZERO,    "SLT_MIN<0");        // 1 (negative < 0)
        check(4'b0111, ZERO,    MIN_INT, "SLT_0<MIN");        // 0
        check(4'b0111, MIN_INT, MAX_INT, "SLT_MIN<MAX");      // 1
        check(4'b0111, MAX_INT, MIN_INT, "SLT_MAX<MIN");      // 0
        check(4'b0111, ALL1,    ZERO,    "SLT_-1<0");         // 1
        check(4'b0111, ZERO,    ALL1,    "SLT_0<-1");         // 0
        edge_cases_2op(4'b0111, "SLT");
        random_loop   (4'b0111, "SLT");

        // ------------------------------------------------------------------ //
        //  SHL  1101                                                          //
        // ------------------------------------------------------------------ //
        $display("=== SHL (1101) ===");
        $display("  [directed] ...");
        check(4'b1101, ZERO,    ZERO, "SHL_0");               // 0<<1=0
        check(4'b1101, ONE,     ZERO, "SHL_1");               // 1<<1=2
        check(4'b1101, MSB,     ZERO, "SHL_MSB");             // carry=1 (MSB evicted), Y=0
        check(4'b1101, MAX_INT, ZERO, "SHL_MAX");             // 7FFF→FFFE, N=1
        check(4'b1101, ALL1,    ZERO, "SHL_FF");              // carry=1 (MSB evicted), Y=0xFFFFFFFE
        check(4'b1101, PAT_AA,  ZERO, "SHL_AA");              // carry=1, MSB was 1
        check(4'b1101, PAT_55,  ZERO, "SHL_55");              // carry=0, MSB was 0
        edge_cases_shift(4'b1101, "SHL");
        random_loop     (4'b1101, "SHL");

        // ------------------------------------------------------------------ //
        //  SHR  1110                                                          //
        // ------------------------------------------------------------------ //
        $display("=== SHR (1110) ===");
        $display("  [directed] ...");
        check(4'b1110, ZERO,    ZERO, "SHR_0");               // 0>>1=0
        check(4'b1110, ONE,     ZERO, "SHR_1");               // carry=1 (MSB evicted), Y=0
        check(4'b1110, MSB,     ZERO, "SHR_MSB");             // carry=0 (LSB was 0), Y=0x4000_0000
        check(4'b1110, ALL1,    ZERO, "SHR_FF");              // carry=1 (MSB evicted), Y=0x7FFF_FFFF
        check(4'b1110, PAT_AA,  ZERO, "SHR_AA");              // carry=0, LSB was 0
        check(4'b1110, PAT_55,  ZERO, "SHR_55");              // carry=1, LSB was 1
        edge_cases_shift(4'b1110, "SHR");
        random_loop     (4'b1110, "SHR");

        // ------------------------------------------------------------------ //
        //  Unknown opcodes — expect Y=0, all flags=0                        //
        // ------------------------------------------------------------------ //
        $display("=== Unknown opcodes ===");
        begin
            automatic logic [3:0] unk [6] = '{
                4'b0100, 4'b0101, 4'b1000,
                4'b1001, 4'b1010, 4'b1111
            };
            foreach (unk[i])
                check(unk[i], 32'hDEAD_BEEF, 32'hCAFE_BABE,
                      $sformatf("UNK_%b", unk[i]));
        end

        // ------------------------------------------------------------------ //
        //  Property : commutativity (ADD, AND, OR, XOR)                     //
        //  f(a,b) == f(b,a) for 500 random pairs per opcode                 //
        // ------------------------------------------------------------------ //
        $display("=== Commutativity check ===");
        begin
            automatic logic [3:0] com_ops [4] = '{
                4'b0010, 4'b0000, 4'b0001, 4'b0011
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
                ALU_control = 4'b0010; A = ra;  B = rb; #1; s    = Y;
                ALU_control = 4'b0110; A = s;   B = rb; #1; back = Y;
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
                ALU_control = 4'b0011; A = ra; B = rb; #1; xr   = Y;
                ALU_control = 4'b0011; A = xr; B = rb; #1; back = Y;
                test_count++;
                if (back !== ra) begin
                    $error("[XOR_inv] (0x%h^0x%h)^0x%h=0x%h, exp=0x%h",
                           ra, rb, rb, back, ra);
                    error_count++;
                end
            end
        end

        // ------------------------------------------------------------------ //
        //  Property : SHL then SHR loses both MSB and LSB                  //
        //  Verify that SHL×1 followed by SHR×1 gives (A & 0x7FFFFFFE)      //
        // ------------------------------------------------------------------ //
        $display("=== SHL then SHR consistency (500 values) ===");
        begin
            logic [DATA_WIDTH-1:0] ra, shifted, back;
            for (int k = 0; k < 500; k++) begin
                ra = $urandom();
                ALU_control = 4'b1101; A = ra;      B = ZERO; #1; shifted = Y;
                ALU_control = 4'b1110; A = shifted; B = ZERO; #1; back    = Y;
                test_count++;
                // SHL(ra)     = {ra[30:0], 1'b0}   — bit[0] becomes 0, ra[31] is evicted
                // SHR(SHL(ra))= {1'b0, ra[30:0]}   — bit[31] becomes 0, ra[0] is restored
                // Net effect  : ra with only bit[31] cleared → ra & 0x7FFFFFFF
                if (back !== (ra & 32'h7FFF_FFFF)) begin
                    $error("[SHL_SHR] ra=0x%h -> SHL=0x%h -> SHR=0x%h, exp=0x%h",
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