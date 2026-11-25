// PURPOSE: Type a character on the PC and its 8-bit code appears on the LEDs.
// Example: typing 'a' (0x61) lights LEDR6, LEDR5 and LEDR0.

// BOARD SIGNALS
//   MAX10_CLK1_50 : the 50 MHz clock input  (so CLKS_PER_BIT = 434 is correct)
//   KEY[0]        : push-button, active LOW; used as reset
//   LEDR[7:0]     : show the last received byte;  LEDR[9:8] stay off

module uart_led_test(
    input        MAX10_CLK1_50,       // 50 MHz clock
    input  [1:0] KEY,                 // push-buttons; KEY[0] = reset
    input        receiver_pin,              // serial input from the USB-UART adapter
    output [9:0] LEDR                 // board LEDs
);
    wire [7:0] data;                  // byte from the receiver
    wire       valid;                 // pulse when a byte arrives
    reg  [7:0] shown;                 // remembers the last byte for the LEDs

    // the receiver under test
    uart_receiver u0 (
        .clk  (MAX10_CLK1_50),
        .rst_n(KEY[0]),
        .rx   (receiver_pin),
        .data (data),
        .valid(valid)
    );

    // hold the most recent byte so it stays on the LEDs (valid only lasts 1 clock)
    always @(posedge MAX10_CLK1_50 or negedge KEY[0])
        if (!KEY[0])    shown <= 8'h00;      // reset clears the LEDs
        else if (valid) shown <= data;       // new byte -> update LEDs

    assign LEDR = {2'b00, shown};
endmodule

