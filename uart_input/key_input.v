// =============================================================================
// key_input.v  -  controller input decoder + input handler
// =============================================================================
// WHAT IT DOES
//   Turns bytes from uart_receiver into the CHIP-8 16-key keypad state that the CPU
//   reads. CHIP-8 keys are numbered 0x0 - 0xF.
//
// PROTOCOL (what the PC script sends, one byte per event)
//     0x80 | k   ->  key k was PRESSED    (e.g. 0x87 = key 7 down)
//     0x00 | k   ->  key k was RELEASED   (e.g. 0x07 = key 7 up)
//   k is 0x0 to 0xF. Any other byte value is ignored.
//
// OUTPUTS (what the CPU / control unit uses)
//     keys[15:0] : keys[k] = 1 while key k is held. Used by the CHIP-8
//                  instructions SKP (EX9E) and SKNP (EXA1): "skip if key VX is
//                  (not) pressed". Several keys can be held at once.
//     last_key   : number of the most recently pressed key. Used by FX0A
//                  ("wait for a key press, store it in VX").
//     key_event  : 1-clock pulse each time a NEW key is pressed, so FX0A knows
//                  when to stop waiting.
//
// 'enable' INPUT
//   The ROM is sent over this same UART wire. While a ROM is loading, 'enable'
//   must be 0, otherwise ROM bytes could look like key presses. While a game
//   runs, 'enable' = 1. (The load/run signal is agreed with the ROM-loader
//   teammate.)
// =============================================================================
module key_input(
    input             clk,
    input             rst_n,          // active-LOW reset
    input             enable,         // 1 = running a game, 0 = loading a ROM
    input      [7:0]  rx_data,        // byte from uart_rx
    input             rx_valid,       // 1-clock pulse from uart_rx: rx_data is new
    output reg [15:0] keys,           // one bit per CHIP-8 key (1 = held)
    output reg [3:0]  last_key,       // last key pressed (for FX0A)
    output reg        key_event       // pulse when a new key is pressed
);

    // ---- combinational decoding of the incoming byte -------------------------
    // A legal key byte looks like 0x00-0x0F (release) or 0x80-0x8F (press), so
    // bits [6:4] must all be 0. Anything else (e.g. ROM data) is ignored.
    wire       is_key  = (rx_data[6:4] == 3'b000);
    wire       pressed = rx_data[7];      // 1 = press, 0 = release
    wire [3:0] key_num = rx_data[3:0];    // which of the 16 keys

    // ---- sequential handler: remembers which keys are held -------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            keys      <= 16'b0;           // nothing held after reset
            last_key  <= 4'd0;
            key_event <= 1'b0;
        end else begin
            key_event <= 1'b0;            // default: pulse lasts one cycle only

            if (!enable) begin
                keys <= 16'b0;            // loading a ROM: release everything
            end
            else if (rx_valid && is_key) begin
                if (pressed) begin
                    keys[key_num] <= 1'b1;    // set this key's bit
                    last_key      <= key_num;
                    key_event     <= 1'b1;
                end else begin
                    keys[key_num] <= 1'b0;    // clear this key's bit
                end
            end
        end
    end
endmodule
