`timescale 1ns/1ps
// =============================================================================
// tb_uart_input.v  -  testbench for uart_rx + key_input   (SIMULATION ONLY)
// =============================================================================
// A testbench is a "fake outside world". It is never put on the FPGA.
// Here it pretends to be the PC: it wiggles the 'rx' wire to send bytes, then
// checks that uart_rx and key_input produce the right outputs and prints
// PASS / FAIL for each check.
//
// To make simulation fast we use CLKS_PER_BIT = 16 instead of 434. The logic is
// the same; only the bit time is shorter.
//
// Run with Icarus Verilog:   iverilog -o sim tb_uart_input.v uart_rx.v key_input.v
//                            vvp sim
// (ModelSim works too: compile the three files and run tb_uart_input.)
// =============================================================================
module test_uart_input;
    localparam CPB = 16;                  // clocks per bit (short, for fast sim)

    reg  clk = 0, rst_n = 0, rx = 1, enable = 1;   // rx idles HIGH
    wire [7:0]  data;   wire valid;                // from uart_rx
    wire [15:0] keys;   wire [3:0] last_key;       // from key_input
    wire        key_event;
    integer     errors = 0;

    // ---- the two modules being tested (called "devices under test") ----------
    uart_receiver   #(.CLKS_PER_BIT(CPB)) u0 (clk, rst_n, rx, data, valid);
    key_input                       u1 (clk, rst_n, enable, data, valid,
                                        keys, last_key, key_event);

    always #10 clk = ~clk;                // 20 ns period = 50 MHz clock

    // ---- task: send one byte over 'rx' the way a UART does -------------------
    task send_byte(input [7:0] b);
        integer i;
        begin
            rx = 0; repeat (CPB) @(posedge clk);                  // start bit (0)
            for (i = 0; i < 8; i = i + 1) begin
                rx = b[i]; repeat (CPB) @(posedge clk);           // data, LSB first
            end
            rx = 1; repeat (CPB) @(posedge clk);                  // stop bit (1)
        end
    endtask

    // ---- task: check the 'keys' output against the expected value ------------
    task expect_keys(input [15:0] exp, input [255:0] name);
        begin
            repeat (4) @(posedge clk);                            // let outputs settle
            if (keys !== exp) begin
                $display("FAIL %0s: keys=%h expected %h", name, keys, exp);
                errors = errors + 1;
            end else
                $display("PASS %0s: keys=%h", name, keys);
        end
    endtask

    // ---- the actual test sequence --------------------------------------------
    initial begin
        // release reset after a few clocks
        repeat (5) @(posedge clk); rst_n = 1; repeat (5) @(posedge clk);

        // TEST 1: uart_rx alone. 0x41 is not a legal key byte, so key_input
        // must ignore it (keys stays 0).
        send_byte(8'h41);
        if (data !== 8'h41) begin $display("FAIL: raw byte"); errors = errors + 1; end
        else                      $display("PASS raw UART byte 41");
        expect_keys(16'h0000, "ignore 0x41");

        // TEST 2: press key 7 -> bit 7 of 'keys' set (0x0080), last_key = 7.
        send_byte(8'h87); expect_keys(16'h0080, "press 7");
        if (last_key !== 4'd7) begin $display("FAIL last_key"); errors = errors + 1; end

        // TEST 3: press key C while 7 is still held -> two keys held at once.
        send_byte(8'h8C); expect_keys(16'h1080, "press C while 7 held (two keys)");

        // TEST 4: release them one at a time.
        send_byte(8'h07); expect_keys(16'h1000, "release 7");
        send_byte(8'h0C); expect_keys(16'h0000, "release C");

        // TEST 5: 'enable' low (ROM loading) must clear keys and block presses.
        send_byte(8'h85); expect_keys(16'h0020, "press 5");
        enable = 0;       repeat (4) @(posedge clk);
        expect_keys(16'h0000, "disable clears keys");
        send_byte(8'h82); expect_keys(16'h0000, "ignored while disabled");

        // ---- summary ----
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d ERRORS", errors);
        $finish;
    end
endmodule

