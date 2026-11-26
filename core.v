module cpu(
    // inputs
	input	    clk, rst, start,
	input	    [15:0] keys,

    // outputs
	output      disp [63:0][31:0],
	output      [15:0] opcode,
);

// register file signals
wire [7:0] rs1data;
wire [7:0] rs2data;
wire [7:0] data_wb;
wire [3:0] rs1x, rs2y, rd;
wire regwren;

// alu signals
wire [3:0] alu_sel;
wire [7:0] alu_result;
wire alu_flag;

// program counter signals
wire [11:0] pc_next;
wire [11:0] PC;
wire pc_enable;
wire pc_load;

// stack signals
wire push, pop;
wire [15:0] stack_data_in;
wire [15:0] stack_data_out;
wire [4:0] sp;
wire stack_full, stack_empty;

    register_file rf_chip8 (
        .clk(clk),
        .rst(rst),
        .rs1x(rs1x),
        .rs2y(rs2y),
        .rd(rd),
        .data_wb(data_wb),
        .regwren(regwren),
        .rs1data(rs1data),
        .rs2data(rs2data)
    );

    alu alu_chip8 (
        .rs1x(rs1data),
        .rs2y(rs2data),
        .sel(alu_sel),
        .data_out(alu_result),
        .flag(alu_flag)
    );

    program_counter pc_chip8 (
        .clk(clk),
        .rst(rst),
        .enable(pc_enable),
        .pc_load(pc_load),
        .pc_next(pc_next),
        .PC(PC)
    );

    stack stack_chip8 (
        .clk(clk),
        .rst(rst),
        .push(push),
        .pop(pop),
        .data_i(stack_data_in),
        .data_o(stack_data_out),
        .sp(sp),
        .full(stack_full),
        .empty(stack_empty)
    );

endmodule : cpu


module alu(
    // inputs
    input [7:0] rs1x,
    input [7:0] rs2y,
    input [3:0] sel,

    // outputs
    output reg [7:0] data_out,
    output reg flag
);

    reg [8:0] temp;

    always @(*) begin
        data_out = 8'd0;
        flag = 1'b0;
        temp = 9'd0;

        case (sel)

            // add: rs1x + rs2y (8XY4)
            4'h0: begin
                temp = {1'b0, rs1x} + {1'b0, rs2y};
                data_out = temp[7:0];
                flag = temp[8];
            end

            // sub: rs1x - rs2y (8XY5)
            4'h1: begin
                temp = {1'b0, rs1x} - {1'b0, rs2y};
                data_out = temp[7:0];
                flag = ~temp[8];
            end

            // reverse sub: rs2y - rs1x (8XY7)
            4'h2: begin
                temp = {1'b0, rs2y} - {1'b0, rs1x};
                data_out = temp[7:0];
                flag = ~temp[8];
            end

            // bitwise OR (8XY1)
            4'h3: begin
                data_out = rs1x | rs2y;
            end

            // bitwise AND (8XY2)
            4'h4: begin
                data_out = rs1x & rs2y;
            end

            // bitwise XOR (8XY3)
            4'h5: begin
                data_out = rs1x ^ rs2y;
            end

            // shift right (8XY6)
            4'h6: begin
                data_out = rs1x >> 1;
                flag = rs1x[0];
            end

            // shift left (8XYE)
            4'h7: begin
                data_out = rs1x << 1;
                flag = rs1x[7];
            end

            default: begin
                data_out = 8'd0;
                flag = 1'b0;
            end

        endcase
    end

endmodule : alu

module register_file (
     // inputs
     input      clk,
     input      rst,
     input      [3:0] rs1x,
     input      [3:0] rs2y,
     input      [3:0] rd,
     input      [7:0] data_wb,
     input      regwren,

     // outputs
     output     reg [7:0] rs1data,
     output     reg [7:0] rs2data
 );
    // creating array of 16 8-bit registers
    reg [7:0] V [0:15];
    integer i;

    // block for writing to register file
    always @(posedge clk or negedge rst) begin
        // reset on signal
        if (rst) begin
            // initialize all register to zero on reset high
            for (i = 0; i < 16; i = i + 1)
                V[i] <= 8'd0;
        end
        // writing back to the register file
        else if (regwren) begin
            V[rd] <= data_wb;
        end
    end

    // block for reading from register file
    always @(*) begin
        rs1data = V[rs1x];
        rs2data = V[rs2y];
    end

endmodule : register_file


module program_counter (
    // inputs
    input clk,
    input rst,
    input enable,
    input pc_load,

    // outputs
    input [11:0] pc_next,
    output reg [11:0] PC
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= 12'h200;
        end
        else if (enable) begin
            if (pc_load)
                PC <= pc_next;
            else
                PC <= PC + 12'd2;
        end
    end

endmodule : program_counter


module stack (
    input clk,
    input rst,

    input push,
    input pop,

    input [15:0] data_i,
    output [15:0] data_o,

    output reg [7:0] SP,
    output full,
    output empty
);

    /* according to space in original interpreters,
   for 16 two-byte entries */
    reg [15:0] stack_space [0:15];

    // flags for minimum and maximum entries
    assign empty = (sp == 0);
    assign full  = (sp == 16);

    // assign top of stack to out
    assign data_o = empty ? 16'd0 : stack_space[SP - 1'b1];

    // push and pop 
    always @(posedge clk or negedge rst) begin
        if (rst) begin
            SP <= 8'd0;
        end
        else begin
            if (push && !full && !pop) begin
                stack_space[sp] <= data_i;
                SP <= SP + 1'b1;
            end
            else if (pop && !empty && !push) begin
                SP <= SP - 1'b1;
            end
        end
    end

endmodule : stack

