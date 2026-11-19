// WHAT IT DOES
//   Listens to one serial wire (rx) coming from the USB-UART adapter and turns
//   the stream of high/low voltages into whole bytes.
//
// HOW A UART BYTE LOOKS ON THE WIRE (line idles HIGH)
//   idle ... START(0) D0 D1 D2 D3 D4 D5 D6 D7 STOP(1) ... idle
//   - Each bit lasts the same time (the "baud rate").
//   - Data bits are sent least-significant bit (D0) first.
//   - No clock wire, so  50,000,000 Hz / 115,200 baud  =  434 clock cycles per bit.
// OUTPUTS
//   data[7:0] : the byte that was received
//   valid     : goes high for exactly ONE clock cycle when a new byte is ready
//               (other modules should grab 'data' while valid = 1)

module uart_receiver #(
    parameter CLKS_PER_BIT = 434      // = clock_frequency / baud_rate 
)(
    input            clk,             // 50 MHz board clock
    input            rst_n,           // active-LOW reset (KEY0 on the DE10-Lite)
    input            rx,              // serial input pin (from adapter TX)
    output reg [7:0] data,            // received byte
    output reg       valid            // 1-clock pulse:
);
    // ---- the 4 states of the receiver's finite state machine (FSM) ----------
    localparam IDLE  = 2'd0,          // waiting for the line to drop (start bit)
               START = 2'd1,          // checking the start bit is real
               DATA  = 2'd2,          // reading the 8 data bits
               STOP  = 2'd3;          // waiting out the stop bit, then output byte

    reg [1:0]  state;                 // current FSM state
    reg [15:0] cnt;                   // counts clock cycles within one bit
    reg [2:0]  idx;                   // which data bit we are reading (0..7)
    reg        s1, s2;                // two flip-flops that "synchronize" rx

    always @(posedge clk) begin
        s1 <= rx;
        s2 <= s1;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset: go back to a known state
            state <= IDLE;
            cnt   <= 0;
            idx   <= 0;
            data  <= 0;
            valid <= 0;
        end else begin
            valid <= 1'b0;            // default: valid is only high for ONE cycle

            case (state)

                // IDLE: line is high. A falling edge (s2 = 0) means a start bit.
                IDLE: begin
                    cnt <= 0;
                    idx <= 0;
                    if (!s2) state <= START;
                end

                // START: wait HALF a bit so we are looking at the MIDDLE of the
                // start bit. If the line is still low there, it's a real start  bit; if it went back high, it was just noise -> go back to IDLE.
                START: begin
                    if (cnt == CLKS_PER_BIT/2 - 1) begin
                        cnt   <= 0;
                        state <= s2 ? IDLE : DATA;
                    end else
                        cnt <= cnt + 1;
                end

                // DATA: from the middle of the start bit, waiting one full bit period lands us in the middle of data bit 0, then bit 1, etc.
                DATA: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt       <= 0;
                        data[idx] <= s2;              // store this bit (LSB first)
                        if (idx == 7) state <= STOP;  // got all 8 bits
                        else          idx   <= idx + 1;
                    end else
                        cnt <= cnt + 1;
                end

                // STOP: wait one more bit period (the stop bit), then announce the finished byte with a one-cycle 'valid' pulse.
                STOP: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt   <= 0;
                        valid <= 1'b1;
                        state <= IDLE;
                    end else
                        cnt <= cnt + 1;
                end

            endcase
        end
    end
endmodule